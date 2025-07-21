const std = @import("std");
const main = @import("main.zig");
const minimp3 = @cImport({
    @cInclude("minimp3_ex.h");
});
const sdl = @import("windowSdl.zig").sdl;

pub const SoundMixer = struct {
    volume: f32 = 1,
    addedSoundDataUntilTimeMs: i64 = 0,
    soundsToPlay: std.ArrayList(SoundToPlay),
    soundData: SoundData = undefined,
};

const SoundToPlay = struct {
    soundIndex: usize,
    dataIndex: usize = 0,
};

const FutureSoundToPlay = struct {
    soundIndex: usize,
    startGameTimeMs: u64,
    mapPosition: main.Position,
};

const SoundFile = struct {
    data: [*]u8,
    len: u32,
    mp3: ?[]i16,
};

pub const SoundData = struct {
    stream: ?*sdl.SDL_AudioStream,
    sounds: []SoundFile,
};

var SOUND_FILE_PATHES = [_][]const u8{
    "sounds/moveNinja.mp3",
    "sounds/moveNinja2.mp3",
    "sounds/moveNinja3.mp3",
    "sounds/bladeCut1.mp3",
    "sounds/bladeCut2.mp3",
    "sounds/bladeCut3.mp3",
    "sounds/bladeCut4.mp3",
    "sounds/bladeDraw.mp3",
};

pub const SOUND_NINJA_MOVE_INDICIES = [_]usize{ 0, 1, 2 };
pub const SOUND_BLADE_CUT_INDICIES = [_]usize{ 3, 4, 5, 6 };
pub const SOUND_BLADE_DRAW = 7;

pub fn createSoundMixer(state: *main.GameState, allocator: std.mem.Allocator) !void {
    state.soundMixer = .{
        .soundsToPlay = std.ArrayList(SoundToPlay).init(allocator),
    };
    state.soundMixer.?.soundData = try initSounds(state, allocator);
}

pub fn destroySoundMixer(state: *main.GameState) void {
    if (state.soundMixer) |*soundMixer| {
        sdl.SDL_DestroyAudioStream(soundMixer.soundData.stream);
        soundMixer.soundsToPlay.deinit();
        for (soundMixer.soundData.sounds) |sound| {
            if (sound.mp3) |dealocate| {
                state.allocator.free(dealocate);
            } else {
                sdl.SDL_free(sound.data);
            }
        }
        state.allocator.free(soundMixer.soundData.sounds);
    }
}

fn cleanUpFinishedSounds(soundMixer: *SoundMixer) void {
    var i: usize = 0;
    while (i < soundMixer.soundsToPlay.items.len) {
        if (soundMixer.soundsToPlay.items[i].dataIndex >= soundMixer.soundData.sounds[soundMixer.soundsToPlay.items[i].soundIndex].len) {
            _ = soundMixer.soundsToPlay.swapRemove(i);
        } else {
            i += 1;
        }
    }
}

fn audioCallback(userdata: ?*anyopaque, stream: ?*sdl.SDL_AudioStream, additional_amount: c_int, len: c_int) callconv(.C) void {
    _ = len;
    const Sample = i16;
    const state: *main.GameState = @ptrCast(@alignCast(userdata.?));
    const soundMixer = &(state.soundMixer.?);
    const sampleCount = @divExact(additional_amount, @sizeOf(Sample));
    var buffer = state.allocator.alloc(Sample, @intCast(sampleCount)) catch return;
    defer state.allocator.free(buffer);
    @memset(buffer, 0);

    var soundCounter: u16 = 0;
    for (soundMixer.soundsToPlay.items) |*sound| {
        soundCounter += 1;
        var i: usize = 0;
        while (i < sampleCount and sound.dataIndex < soundMixer.soundData.sounds[sound.soundIndex].len) {
            const data: [*]Sample = @ptrCast(@alignCast(soundMixer.soundData.sounds[sound.soundIndex].data));
            buffer[i] +|= @intFromFloat(@as(f64, @floatFromInt(data[@divFloor(sound.dataIndex, 2)])) * soundMixer.volume);
            i += 1;
            sound.dataIndex += 2;
        }
    }
    if (soundCounter > 0) {
        const powY = @sqrt(@as(f32, @floatFromInt(soundCounter - 1)));
        const soundCountVolumeFactor: f32 = std.math.pow(f32, 0.8, powY);
        for (0..buffer.len) |index| {
            buffer[index] = @intFromFloat(@as(f32, @floatFromInt(buffer[index])) * soundCountVolumeFactor);
        }
    }
    _ = sdl.SDL_PutAudioStreamData(stream, buffer.ptr, additional_amount);
    cleanUpFinishedSounds(soundMixer);
}

pub fn playRandomSound(optSoundMixer: *?SoundMixer, soundIndex: []const usize, offset: usize) !void {
    const rand = std.crypto.random;
    const randomIndex: usize = @as(usize, @intFromFloat(rand.float(f32) * @as(f32, @floatFromInt(soundIndex.len))));
    if (optSoundMixer.*) |*soundMixer| {
        try soundMixer.soundsToPlay.append(.{
            .soundIndex = soundIndex[randomIndex],
            .dataIndex = offset,
        });
    }
}

pub fn playSound(optSoundMixer: *?SoundMixer, soundIndex: usize, offset: usize) !void {
    if (optSoundMixer.*) |*soundMixer| {
        try soundMixer.soundsToPlay.append(.{
            .soundIndex = soundIndex,
            .dataIndex = offset,
        });
    }
}

fn initSounds(state: *main.GameState, allocator: std.mem.Allocator) !SoundData {
    var desired_spec = sdl.SDL_AudioSpec{
        .format = sdl.SDL_AUDIO_S16,
        .freq = 48000,
        .channels = 1,
    };
    const sounds = try allocator.alloc(SoundFile, SOUND_FILE_PATHES.len);
    for (0..SOUND_FILE_PATHES.len) |i| {
        sounds[i] = try loadSoundFile(SOUND_FILE_PATHES[i], allocator);
    }

    const stream = sdl.SDL_OpenAudioDeviceStream(sdl.SDL_AUDIO_DEVICE_DEFAULT_PLAYBACK, &desired_spec, audioCallback, state);
    if (stream == null) {
        return error.createAudioStream;
    }
    const device = sdl.SDL_GetAudioStreamDevice(stream);
    if (device == 0) {
        return error.openAudioDevice;
    }
    if (!sdl.SDL_ResumeAudioDevice(device)) {
        return error.resumeAudioDevice;
    }
    return .{
        .stream = stream,
        .sounds = sounds,
    };
}

///support wav and mp3
fn loadSoundFile(path: []const u8, allocator: std.mem.Allocator) !SoundFile {
    var audio_buf: [*]u8 = undefined;
    var audio_len: u32 = 0;
    if (std.mem.endsWith(u8, path, ".wav")) {
        var spec: sdl.SDL_AudioSpec = undefined;
        if (!sdl.SDL_LoadWAV(@ptrCast(path), &spec, @ptrCast(&audio_buf), &audio_len)) {
            return error.loadWav;
        }

        return .{ .data = audio_buf, .len = audio_len, .mp3 = null };
        // defer sdl.SDL_free(audio_buf);
    } else if (std.mem.endsWith(u8, path, ".mp3")) {
        var mp3 = minimp3.mp3dec_ex_t{};
        if (minimp3.mp3dec_ex_open(&mp3, path.ptr, minimp3.MP3D_SEEK_TO_SAMPLE) != 0) {
            return error.openMp3;
        }
        defer minimp3.mp3dec_ex_close(&mp3);
        // Allocate your own buffer for the decoded samples
        const total_samples = mp3.samples; // number of samples (not bytes)
        const sample_count: usize = @intCast(total_samples);
        const decoded = try allocator.alloc(i16, sample_count);

        // Read all samples
        const samples_read = minimp3.mp3dec_ex_read(&mp3, decoded.ptr, sample_count);
        audio_buf = @ptrCast(decoded.ptr);
        audio_len = @intCast(samples_read * @sizeOf(i16));
        return .{ .data = audio_buf, .len = audio_len, .mp3 = decoded };
    } else {
        return error.unknwonSoundFileType;
    }
}
