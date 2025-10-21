const std = @import("std");
const main = @import("../main.zig");
const windowSdlZig = @import("../windowSdl.zig");
const sdl = windowSdlZig.sdl;
const imageZig = @import("../image.zig");
const paintVulkanZig = @import("paintVulkan.zig");
const dataVulkanZig = @import("dataVulkan.zig");
const pipelinesVulkanZig = @import("pipelinesVulkan.zig");
const fontVulkanZig = @import("fontVulkan.zig");
const settingsMenuVulkanZig = @import("settingsMenuVulkan.zig");

pub const vk = @cImport({
    @cInclude("Volk/volk.h");
});

const DEFAULT_VERTEX_BUFFER_INITIAL_SIZE = 1000;
const ENABLE_VALIDATION_LAYER = false;
pub const VALIDATION_LAYERS = [_][*c]const u8{"VK_LAYER_KHRONOS_validation"};

pub const VkState = struct {
    instance: vk.VkInstance = undefined,
    surface: vk.VkSurfaceKHR = undefined,
    graphicsQueueFamilyIdx: u32 = undefined,
    physicalDevice: vk.VkPhysicalDevice = undefined,
    logicalDevice: vk.VkDevice = undefined,
    queue: vk.VkQueue = undefined,
    swapchain: vk.VkSwapchainKHR = undefined,
    swapchainInfo: struct {
        support: SwapChainSupportDetails = undefined,
        format: vk.VkSurfaceFormatKHR = undefined,
        present: vk.VkPresentModeKHR = undefined,
        extent: vk.VkExtent2D = undefined,
        images: []vk.VkImage = &.{},
    } = undefined,
    swapchainImageviews: []vk.VkImageView = undefined,
    renderPass: vk.VkRenderPass = undefined,
    msaaSamples: vk.VkSampleCountFlagBits = vk.VK_SAMPLE_COUNT_1_BIT,
    descriptorSetLayout: vk.VkDescriptorSetLayout = undefined,
    pipelineLayout: vk.VkPipelineLayout = undefined,
    graphicsPipelines: pipelinesVulkanZig.VkPipelines = undefined,
    depth: struct {
        image: vk.VkImage = undefined,
        imageMemory: vk.VkDeviceMemory = undefined,
        imageView: vk.VkImageView = undefined,
    } = undefined,
    color: struct {
        image: vk.VkImage = undefined,
        imageMemory: vk.VkDeviceMemory = undefined,
        imageView: vk.VkImageView = undefined,
    } = undefined,
    spriteImages: struct {
        mipLevels: []u32 = undefined,
        textureImage: []vk.VkImage = undefined,
        textureImageMemory: []vk.VkDeviceMemory = undefined,
        textureImageView: []vk.VkImageView = undefined,
    } = undefined,
    framebuffers: ?[]vk.VkFramebuffer = null,
    commandPool: vk.VkCommandPool = undefined,
    textureSampler: vk.VkSampler = undefined,
    uniformBuffers: []vk.VkBuffer = undefined,
    uniformBuffersMemory: []vk.VkDeviceMemory = undefined,
    uniformBuffersMapped: []?*anyopaque = undefined,
    descriptorPool: vk.VkDescriptorPool = undefined,
    descriptorSets: []vk.VkDescriptorSet = undefined,
    commandBuffer: []vk.VkCommandBuffer = undefined,
    imageAvailableSemaphore: []vk.VkSemaphore = undefined,
    submitSemaphores: []vk.VkSemaphore = undefined,
    inFlightFence: []vk.VkFence = undefined,
    currentFrame: u16 = 0,

    verticeData: dataVulkanZig.VkVerticeData = .{},
    font: fontVulkanZig.VkFontData = .{},
    pub const MAX_FRAMES_IN_FLIGHT: u16 = 2;
    pub const BUFFER_ADDITIOAL_SIZE: u16 = 50;
};

const QueueFamilyIndices = struct {
    graphicsFamily: ?u32,
    presentFamily: ?u32,

    fn isComplete(self: QueueFamilyIndices) bool {
        return self.graphicsFamily != null;
    }
};

const SwapChainSupportDetails = struct {
    capabilities: vk.VkSurfaceCapabilitiesKHR,
    formats: []vk.VkSurfaceFormatKHR,
    presentModes: []vk.VkPresentModeKHR,
};

pub fn initVulkan(state: *main.GameState) !void {
    const vkState = &state.vkState;

    const vulkanInstanceProcAddr = sdl.SDL_Vulkan_GetVkGetInstanceProcAddr();
    const vkGetInstanceProcAddr: vk.PFN_vkGetInstanceProcAddr = @ptrCast(vulkanInstanceProcAddr);
    vk.volkInitializeCustom(vkGetInstanceProcAddr);

    try createInstance(vkState, state.allocator);
    vk.volkLoadInstance(vkState.instance);
    vkState.surface = @ptrCast(windowSdlZig.getSurfaceForVulkan(@ptrCast(vkState.instance), state));
    vkState.physicalDevice = try pickPhysicalDevice(vkState.instance, vkState, state.allocator);
    try createLogicalDevice(vkState.physicalDevice, vkState);
    try createSwapChain(vkState, state);
    try createImageViews(vkState, state.allocator);
    try createRenderPass(vkState, state.allocator);
    try createDescriptorSetLayout(vkState);
    try pipelinesVulkanZig.createGraphicsPipelines(vkState, state.allocator);
    try createColorResources(vkState);
    try createDepthResources(vkState, state.allocator);
    try createFramebuffers(vkState, state.allocator);
    try createCommandPool(vkState, state.allocator);
    try imageZig.createVulkanTextureSprites(vkState, state.allocator);
    try createTextureSampler(vkState);
    try createVertexBuffer(vkState, state.allocator);
    try fontVulkanZig.initFont(state);
    try createUniformBuffers(vkState, state.allocator);
    try createDescriptorPool(vkState);
    try createDescriptorSets(vkState, state.allocator);
    try createCommandBuffers(vkState, state.allocator);
    try createSyncObjects(vkState, state.allocator);
    settingsMenuVulkanZig.setupUiLocations(state);
    std.debug.print("finished vulkan setup \n", .{});
}

pub fn destroyPaintVulkan(vkState: *VkState, allocator: std.mem.Allocator) !void {
    if (vk.vkDeviceWaitIdle.?(vkState.logicalDevice) != vk.VK_SUCCESS) return error.vkDeviceWaitIdleDestroyPaintVulkan;
    fontVulkanZig.destroyFont(vkState);
    destroyVerticeData(vkState, allocator);
    cleanupSwapChain(vkState, allocator);

    for (0..VkState.MAX_FRAMES_IN_FLIGHT) |i| {
        vk.vkDestroySemaphore.?(vkState.logicalDevice, vkState.imageAvailableSemaphore[i], null);
        vk.vkDestroyFence.?(vkState.logicalDevice, vkState.inFlightFence[i], null);
    }
    for (0..vkState.submitSemaphores.len) |i| {
        vk.vkDestroySemaphore.?(vkState.logicalDevice, vkState.submitSemaphores[i], null);
    }

    for (0..VkState.MAX_FRAMES_IN_FLIGHT) |i| {
        vk.vkDestroyBuffer.?(vkState.logicalDevice, vkState.uniformBuffers[i], null);
        vk.vkFreeMemory.?(vkState.logicalDevice, vkState.uniformBuffersMemory[i], null);
    }
    vk.vkDestroySampler.?(vkState.logicalDevice, vkState.textureSampler, null);

    for (0..imageZig.IMAGE_DATA.len) |i| {
        vk.vkDestroyImageView.?(vkState.logicalDevice, vkState.spriteImages.textureImageView[i], null);
        vk.vkDestroyImage.?(vkState.logicalDevice, vkState.spriteImages.textureImage[i], null);
        vk.vkFreeMemory.?(vkState.logicalDevice, vkState.spriteImages.textureImageMemory[i], null);
    }

    vk.vkDestroyDescriptorPool.?(vkState.logicalDevice, vkState.descriptorPool, null);
    vk.vkDestroyDescriptorSetLayout.?(vkState.logicalDevice, vkState.descriptorSetLayout, null);
    vk.vkDestroyCommandPool.?(vkState.logicalDevice, vkState.commandPool, null);
    pipelinesVulkanZig.destroy(vkState);
    vk.vkDestroyPipelineLayout.?(vkState.logicalDevice, vkState.pipelineLayout, null);
    vk.vkDestroyRenderPass.?(vkState.logicalDevice, vkState.renderPass, null);
    vk.vkDestroyDevice.?(vkState.logicalDevice, null);
    vk.vkDestroySurfaceKHR.?(vkState.instance, vkState.surface, null);
    vk.vkDestroyInstance.?(vkState.instance, null);
    allocator.free(vkState.uniformBuffers);
    allocator.free(vkState.uniformBuffersMemory);
    allocator.free(vkState.uniformBuffersMapped);
    allocator.free(vkState.spriteImages.textureImageView);
    allocator.free(vkState.descriptorSets);
    allocator.free(vkState.imageAvailableSemaphore);
    allocator.free(vkState.submitSemaphores);
    allocator.free(vkState.inFlightFence);
    allocator.free(vkState.commandBuffer);
    allocator.free(vkState.spriteImages.textureImage);
    allocator.free(vkState.spriteImages.textureImageMemory);
    allocator.free(vkState.spriteImages.mipLevels);
}

fn destroyVerticeData(vkState: *VkState, allocator: std.mem.Allocator) void {
    const verticeData = &vkState.verticeData;
    for (0..VkState.MAX_FRAMES_IN_FLIGHT) |i| {
        if (verticeData.triangles.vertexBufferCleanUp[i] != null) {
            vk.vkDestroyBuffer.?(vkState.logicalDevice, verticeData.triangles.vertexBufferCleanUp[i].?, null);
            vk.vkFreeMemory.?(vkState.logicalDevice, verticeData.triangles.vertexBufferMemoryCleanUp[i].?, null);
            verticeData.triangles.vertexBufferCleanUp[i] = null;
            verticeData.triangles.vertexBufferMemoryCleanUp[i] = null;
        }
        if (verticeData.lines.vertexBufferCleanUp[i] != null) {
            vk.vkDestroyBuffer.?(vkState.logicalDevice, verticeData.lines.vertexBufferCleanUp[i].?, null);
            vk.vkFreeMemory.?(vkState.logicalDevice, verticeData.lines.vertexBufferMemoryCleanUp[i].?, null);
            verticeData.lines.vertexBufferCleanUp[i] = null;
            verticeData.lines.vertexBufferMemoryCleanUp[i] = null;
        }
        if (verticeData.sprites.vertexBufferCleanUp[i] != null) {
            vk.vkDestroyBuffer.?(vkState.logicalDevice, verticeData.sprites.vertexBufferCleanUp[i].?, null);
            vk.vkFreeMemory.?(vkState.logicalDevice, verticeData.sprites.vertexBufferMemoryCleanUp[i].?, null);
            verticeData.sprites.vertexBufferCleanUp[i] = null;
            verticeData.sprites.vertexBufferMemoryCleanUp[i] = null;
        }
        if (verticeData.spritesComplex.vertexBufferCleanUp[i] != null) {
            vk.vkDestroyBuffer.?(vkState.logicalDevice, verticeData.spritesComplex.vertexBufferCleanUp[i].?, null);
            vk.vkFreeMemory.?(vkState.logicalDevice, verticeData.spritesComplex.vertexBufferMemoryCleanUp[i].?, null);
            verticeData.spritesComplex.vertexBufferCleanUp[i] = null;
            verticeData.spritesComplex.vertexBufferMemoryCleanUp[i] = null;
        }
        if (verticeData.font.vertexBufferCleanUp[i] != null) {
            vk.vkDestroyBuffer.?(vkState.logicalDevice, verticeData.font.vertexBufferCleanUp[i].?, null);
            vk.vkFreeMemory.?(vkState.logicalDevice, verticeData.font.vertexBufferMemoryCleanUp[i].?, null);
            verticeData.font.vertexBufferCleanUp[i] = null;
            verticeData.font.vertexBufferMemoryCleanUp[i] = null;
        }
    }
    vk.vkDestroyBuffer.?(vkState.logicalDevice, verticeData.triangles.vertexBuffer, null);
    vk.vkDestroyBuffer.?(vkState.logicalDevice, verticeData.lines.vertexBuffer, null);
    vk.vkDestroyBuffer.?(vkState.logicalDevice, verticeData.sprites.vertexBuffer, null);
    vk.vkDestroyBuffer.?(vkState.logicalDevice, verticeData.spritesComplex.vertexBuffer, null);
    vk.vkDestroyBuffer.?(vkState.logicalDevice, verticeData.font.vertexBuffer, null);
    vk.vkFreeMemory.?(vkState.logicalDevice, verticeData.triangles.vertexBufferMemory, null);
    vk.vkFreeMemory.?(vkState.logicalDevice, verticeData.lines.vertexBufferMemory, null);
    vk.vkFreeMemory.?(vkState.logicalDevice, verticeData.sprites.vertexBufferMemory, null);
    vk.vkFreeMemory.?(vkState.logicalDevice, verticeData.spritesComplex.vertexBufferMemory, null);
    vk.vkFreeMemory.?(vkState.logicalDevice, verticeData.font.vertexBufferMemory, null);
    allocator.free(verticeData.triangles.vertices);
    allocator.free(verticeData.triangles.vertexBufferCleanUp);
    allocator.free(verticeData.triangles.vertexBufferMemoryCleanUp);
    allocator.free(verticeData.lines.vertices);
    allocator.free(verticeData.lines.vertexBufferCleanUp);
    allocator.free(verticeData.lines.vertexBufferMemoryCleanUp);
    allocator.free(verticeData.sprites.vertices);
    allocator.free(verticeData.sprites.vertexBufferCleanUp);
    allocator.free(verticeData.sprites.vertexBufferMemoryCleanUp);
    allocator.free(verticeData.spritesComplex.vertices);
    allocator.free(verticeData.spritesComplex.vertexBufferCleanUp);
    allocator.free(verticeData.spritesComplex.vertexBufferMemoryCleanUp);
    allocator.free(verticeData.font.vertices);
    allocator.free(verticeData.font.vertexBufferCleanUp);
    allocator.free(verticeData.font.vertexBufferMemoryCleanUp);
    verticeData.dataDrawCut.deinit();
}

fn cleanupSwapChain(vkState: *VkState, allocator: std.mem.Allocator) void {
    vk.vkDestroyImageView.?(vkState.logicalDevice, vkState.depth.imageView, null);
    vk.vkDestroyImage.?(vkState.logicalDevice, vkState.depth.image, null);
    vk.vkFreeMemory.?(vkState.logicalDevice, vkState.depth.imageMemory, null);
    vk.vkDestroyImageView.?(vkState.logicalDevice, vkState.color.imageView, null);
    vk.vkDestroyImage.?(vkState.logicalDevice, vkState.color.image, null);
    vk.vkFreeMemory.?(vkState.logicalDevice, vkState.color.imageMemory, null);
    for (vkState.swapchainImageviews) |imgvw| {
        vk.vkDestroyImageView.?(vkState.logicalDevice, imgvw, null);
    }
    allocator.free(vkState.swapchainImageviews);
    for (vkState.framebuffers.?) |fb| {
        vk.vkDestroyFramebuffer.?(vkState.logicalDevice, fb, null);
    }
    vk.vkDestroySwapchainKHR.?(vkState.logicalDevice, vkState.swapchain, null);
    allocator.free(vkState.framebuffers.?);
    vkState.framebuffers = null;
    allocator.free(vkState.swapchainInfo.images);
    allocator.free(vkState.swapchainInfo.support.formats);
    allocator.free(vkState.swapchainInfo.support.presentModes);
}

fn createInstance(vkState: *VkState, allocator: std.mem.Allocator) !void {
    var app_info = vk.VkApplicationInfo{
        .sType = vk.VK_STRUCTURE_TYPE_APPLICATION_INFO,
        .pNext = null,
        .pApplicationName = "SpeedNinja",
        .applicationVersion = vk.VK_MAKE_VERSION(1, 0, 0),
        .pEngineName = "No Engine",
        .engineVersion = vk.VK_MAKE_VERSION(1, 0, 0),
        .apiVersion = vk.VK_API_VERSION_1_2,
    };
    var instance_create_info = vk.VkInstanceCreateInfo{
        .sType = vk.VK_STRUCTURE_TYPE_INSTANCE_CREATE_INFO,
        .pNext = null,
        .flags = 0,
        .pApplicationInfo = &app_info,
        .enabledExtensionCount = 0,
        .ppEnabledExtensionNames = null,
    };
    if (ENABLE_VALIDATION_LAYER) {
        std.debug.print("!!!!!!!vulkan validation layers enabled!!!!!!\n", .{});
        instance_create_info.enabledLayerCount = VALIDATION_LAYERS.len;
        instance_create_info.ppEnabledLayerNames = &VALIDATION_LAYERS;
    }

    const requiredExtensions = [_][*:0]const u8{};

    var extension_list = std.ArrayList([*c]const u8).init(allocator);
    for (requiredExtensions[0..requiredExtensions.len]) |ext| {
        try extension_list.append(ext);
    }

    try extension_list.append(vk.VK_EXT_DEBUG_UTILS_EXTENSION_NAME);
    const extensions_ = try extension_list.toOwnedSlice();
    defer allocator.free(extensions_);

    var extCount: c_uint = 0;
    instance_create_info.ppEnabledExtensionNames = sdl.SDL_Vulkan_GetInstanceExtensions(&extCount);
    instance_create_info.enabledExtensionCount = extCount;

    try vkcheck(vk.vkCreateInstance.?(&instance_create_info, null, &vkState.instance), "failed vkCreateInstance");
}

fn pickPhysicalDevice(instance: vk.VkInstance, vkState: *VkState, allocator: std.mem.Allocator) !vk.VkPhysicalDevice {
    var device_count: u32 = 0;
    try vkcheck(vk.vkEnumeratePhysicalDevices.?(instance, &device_count, null), "Failed to enumerate physical devices");
    if (device_count == 0) {
        return error.NoGPUsWithVulkanSupport;
    }

    const devices = try allocator.alloc(vk.VkPhysicalDevice, device_count);
    defer allocator.free(devices);
    try vkcheck(vk.vkEnumeratePhysicalDevices.?(instance, &device_count, devices.ptr), "Failed to enumerate physical devices");

    var bestScore: u32 = 0;
    var bestDevice: ?vk.VkPhysicalDevice = null;
    for (devices) |device| {
        const score = try isDeviceSuitable(device, vkState, allocator);
        if (score > bestScore) {
            bestScore = score;
            bestDevice = device;
        }
    }
    if (bestDevice) |device| {
        vkState.msaaSamples = getMaxUsableSampleCount(device);
        return device;
    }
    return error.NoSuitableGPU;
}

fn createLogicalDevice(physicalDevice: vk.VkPhysicalDevice, vkState: *VkState) !void {
    var queue_create_info = vk.VkDeviceQueueCreateInfo{
        .sType = vk.VK_STRUCTURE_TYPE_DEVICE_QUEUE_CREATE_INFO,
        .queueFamilyIndex = vkState.graphicsQueueFamilyIdx,
        .queueCount = 1,
        .pQueuePriorities = &[_]f32{1.0},
    };
    const device_features = vk.VkPhysicalDeviceFeatures{
        .samplerAnisotropy = vk.VK_TRUE,
        .geometryShader = vk.VK_TRUE,
        .fillModeNonSolid = vk.VK_TRUE,
    };
    var vk12Features = vk.VkPhysicalDeviceVulkan12Features{
        .sType = vk.VK_STRUCTURE_TYPE_PHYSICAL_DEVICE_VULKAN_1_2_FEATURES,
        .shaderSampledImageArrayNonUniformIndexing = vk.VK_TRUE,
        .runtimeDescriptorArray = vk.VK_TRUE,
    };
    var deviceFeatures: vk.VkPhysicalDeviceFeatures2 = .{
        .sType = vk.VK_STRUCTURE_TYPE_PHYSICAL_DEVICE_FEATURES_2,
        .pNext = &vk12Features,
        .features = device_features,
    };
    var device_create_info = vk.VkDeviceCreateInfo{
        .sType = vk.VK_STRUCTURE_TYPE_DEVICE_CREATE_INFO,
        .pNext = &deviceFeatures,
        .pQueueCreateInfos = &queue_create_info,
        .queueCreateInfoCount = 1,
        .pEnabledFeatures = null,
        .enabledExtensionCount = 1,
        .ppEnabledExtensionNames = &[_][*c]const u8{vk.VK_KHR_SWAPCHAIN_EXTENSION_NAME},
    };
    if (ENABLE_VALIDATION_LAYER) {
        device_create_info.enabledLayerCount = VALIDATION_LAYERS.len;
        device_create_info.ppEnabledLayerNames = &VALIDATION_LAYERS;
    }
    try vkcheck(vk.vkCreateDevice.?(physicalDevice, &device_create_info, null, &vkState.logicalDevice), "Failed to create logical device");
    vk.vkGetDeviceQueue.?(vkState.logicalDevice, vkState.graphicsQueueFamilyIdx, 0, &vkState.queue);
}

fn createSwapChain(vkState: *VkState, state: *main.GameState) !void {
    vkState.swapchainInfo.support = try querySwapChainSupport(vkState, state.allocator);
    vkState.swapchainInfo.format = chooseSwapSurfaceFormat(vkState.swapchainInfo.support.formats);
    vkState.swapchainInfo.present = chooseSwapPresentMode(vkState.swapchainInfo.support.presentModes);
    vkState.swapchainInfo.extent = chooseSwapExtent(vkState.swapchainInfo.support.capabilities, state);

    var imageCount = vkState.swapchainInfo.support.capabilities.minImageCount + 1;
    if (vkState.swapchainInfo.support.capabilities.maxImageCount > 0 and imageCount > vkState.swapchainInfo.support.capabilities.maxImageCount) {
        imageCount = vkState.swapchainInfo.support.capabilities.maxImageCount;
    }

    var createInfo = vk.VkSwapchainCreateInfoKHR{
        .sType = vk.VK_STRUCTURE_TYPE_SWAPCHAIN_CREATE_INFO_KHR,
        .surface = vkState.surface,
        .minImageCount = imageCount,
        .imageFormat = vkState.swapchainInfo.format.format,
        .imageColorSpace = vkState.swapchainInfo.format.colorSpace,
        .imageExtent = vkState.swapchainInfo.extent,
        .imageArrayLayers = 1,
        .imageUsage = vk.VK_IMAGE_USAGE_COLOR_ATTACHMENT_BIT,
        .preTransform = vkState.swapchainInfo.support.capabilities.currentTransform,
        .compositeAlpha = vk.VK_COMPOSITE_ALPHA_OPAQUE_BIT_KHR,
        .presentMode = vkState.swapchainInfo.present,
        .clipped = vk.VK_TRUE,
        .oldSwapchain = null,
    };

    const indices = try findQueueFamilies(vkState.physicalDevice, vkState, state.allocator);
    const queueFamilyIndices = [_]u32{ indices.graphicsFamily.?, indices.presentFamily.? };
    if (indices.graphicsFamily != indices.presentFamily) {
        createInfo.imageSharingMode = vk.VK_SHARING_MODE_CONCURRENT;
        createInfo.queueFamilyIndexCount = 2;
        createInfo.pQueueFamilyIndices = &queueFamilyIndices;
    } else {
        createInfo.imageSharingMode = vk.VK_SHARING_MODE_EXCLUSIVE;
    }

    try vkcheck(vk.vkCreateSwapchainKHR.?(vkState.logicalDevice, &createInfo, null, &vkState.swapchain), "Failed to create swapchain KHR");

    try vkcheck(vk.vkGetSwapchainImagesKHR.?(vkState.logicalDevice, vkState.swapchain, &imageCount, null), "failed vkGetSwapchainImagesKHR");
    vkState.swapchainInfo.images = try state.allocator.alloc(vk.VkImage, imageCount);
    try vkcheck(vk.vkGetSwapchainImagesKHR.?(vkState.logicalDevice, vkState.swapchain, &imageCount, vkState.swapchainInfo.images.ptr), "failed vkGetSwapchainImagesKHR");
}

fn createImageViews(vkState: *VkState, allocator: std.mem.Allocator) !void {
    vkState.swapchainImageviews = try allocator.alloc(vk.VkImageView, vkState.swapchainInfo.images.len);
    for (vkState.swapchainInfo.images, 0..) |image, i| {
        vkState.swapchainImageviews[i] = try createImageView(image, vkState.swapchainInfo.format.format, 1, vk.VK_IMAGE_ASPECT_COLOR_BIT, vkState);
    }
}

fn createRenderPass(vkState: *VkState, allocator: std.mem.Allocator) !void {
    const colorAttachment = vk.VkAttachmentDescription{
        .format = vkState.swapchainInfo.format.format,
        .samples = vkState.msaaSamples,
        .loadOp = vk.VK_ATTACHMENT_LOAD_OP_CLEAR,
        .storeOp = vk.VK_ATTACHMENT_STORE_OP_STORE,
        .stencilLoadOp = vk.VK_ATTACHMENT_LOAD_OP_DONT_CARE,
        .stencilStoreOp = vk.VK_ATTACHMENT_STORE_OP_DONT_CARE,
        .initialLayout = vk.VK_IMAGE_LAYOUT_UNDEFINED,
        .finalLayout = vk.VK_IMAGE_LAYOUT_COLOR_ATTACHMENT_OPTIMAL,
    };

    var colorAttachmentRef = vk.VkAttachmentReference{
        .attachment = 0,
        .layout = vk.VK_IMAGE_LAYOUT_COLOR_ATTACHMENT_OPTIMAL,
    };
    const colorAttachmentResolve: vk.VkAttachmentDescription = .{
        .format = vkState.swapchainInfo.format.format,
        .samples = vk.VK_SAMPLE_COUNT_1_BIT,
        .loadOp = vk.VK_ATTACHMENT_LOAD_OP_DONT_CARE,
        .storeOp = vk.VK_ATTACHMENT_STORE_OP_STORE,
        .stencilLoadOp = vk.VK_ATTACHMENT_LOAD_OP_DONT_CARE,
        .stencilStoreOp = vk.VK_ATTACHMENT_STORE_OP_DONT_CARE,
        .initialLayout = vk.VK_IMAGE_LAYOUT_UNDEFINED,
        .finalLayout = vk.VK_IMAGE_LAYOUT_PRESENT_SRC_KHR,
    };
    var colorAttachmentResolveRef = vk.VkAttachmentReference{
        .attachment = 2,
        .layout = vk.VK_IMAGE_LAYOUT_COLOR_ATTACHMENT_OPTIMAL,
    };

    const depthAttachment: vk.VkAttachmentDescription = .{
        .format = try findDepthFormat(vkState, allocator),
        .samples = vkState.msaaSamples,
        .loadOp = vk.VK_ATTACHMENT_LOAD_OP_CLEAR,
        .storeOp = vk.VK_ATTACHMENT_STORE_OP_DONT_CARE,
        .stencilLoadOp = vk.VK_ATTACHMENT_LOAD_OP_DONT_CARE,
        .stencilStoreOp = vk.VK_ATTACHMENT_STORE_OP_DONT_CARE,
        .initialLayout = vk.VK_IMAGE_LAYOUT_UNDEFINED,
        .finalLayout = vk.VK_IMAGE_LAYOUT_DEPTH_STENCIL_ATTACHMENT_OPTIMAL,
    };

    const subpassLayer1 = vk.VkSubpassDescription{
        .pipelineBindPoint = vk.VK_PIPELINE_BIND_POINT_GRAPHICS,
        .colorAttachmentCount = 1,
        .pColorAttachments = &colorAttachmentRef,
        .pResolveAttachments = &colorAttachmentResolveRef,
    };
    const subpasses = [_]vk.VkSubpassDescription{subpassLayer1};

    const dependency: vk.VkSubpassDependency = .{
        .srcSubpass = vk.VK_SUBPASS_EXTERNAL,
        .dstSubpass = 0,
        .srcStageMask = vk.VK_PIPELINE_STAGE_COLOR_ATTACHMENT_OUTPUT_BIT | vk.VK_PIPELINE_STAGE_EARLY_FRAGMENT_TESTS_BIT,
        .srcAccessMask = 0,
        .dstStageMask = vk.VK_PIPELINE_STAGE_COLOR_ATTACHMENT_OUTPUT_BIT | vk.VK_PIPELINE_STAGE_EARLY_FRAGMENT_TESTS_BIT,
        .dstAccessMask = vk.VK_ACCESS_COLOR_ATTACHMENT_WRITE_BIT | vk.VK_ACCESS_DEPTH_STENCIL_ATTACHMENT_WRITE_BIT,
    };

    const attachments = [_]vk.VkAttachmentDescription{ colorAttachment, depthAttachment, colorAttachmentResolve };
    const dependencies = [_]vk.VkSubpassDependency{dependency};
    var renderPassInfo = vk.VkRenderPassCreateInfo{
        .sType = vk.VK_STRUCTURE_TYPE_RENDER_PASS_CREATE_INFO,
        .attachmentCount = attachments.len,
        .pAttachments = &attachments,
        .subpassCount = subpasses.len,
        .pSubpasses = &subpasses,
        .dependencyCount = dependencies.len,
        .pDependencies = &dependencies,
    };
    try vkcheck(vk.vkCreateRenderPass.?(vkState.logicalDevice, &renderPassInfo, null, &vkState.renderPass), "Failed to create Render Pass.");
}

fn createDescriptorSetLayout(vkState: *VkState) !void {
    const uboLayoutBinding: vk.VkDescriptorSetLayoutBinding = .{
        .binding = 0,
        .descriptorType = vk.VK_DESCRIPTOR_TYPE_UNIFORM_BUFFER,
        .descriptorCount = 1,
        .pImmutableSamplers = null,
        .stageFlags = vk.VK_SHADER_STAGE_VERTEX_BIT | vk.VK_SHADER_STAGE_GEOMETRY_BIT,
    };
    const samplerLayoutBinding: vk.VkDescriptorSetLayoutBinding = .{
        .binding = 1,
        .descriptorCount = imageZig.IMAGE_DATA.len,
        .descriptorType = vk.VK_DESCRIPTOR_TYPE_COMBINED_IMAGE_SAMPLER,
        .pImmutableSamplers = null,
        .stageFlags = vk.VK_SHADER_STAGE_FRAGMENT_BIT,
    };
    const samplerLayoutFontBinding: vk.VkDescriptorSetLayoutBinding = .{
        .binding = 2,
        .descriptorCount = 1,
        .descriptorType = vk.VK_DESCRIPTOR_TYPE_COMBINED_IMAGE_SAMPLER,
        .pImmutableSamplers = null,
        .stageFlags = vk.VK_SHADER_STAGE_FRAGMENT_BIT,
    };

    const bindings = [_]vk.VkDescriptorSetLayoutBinding{ uboLayoutBinding, samplerLayoutBinding, samplerLayoutFontBinding };

    const layoutInfo: vk.VkDescriptorSetLayoutCreateInfo = .{
        .sType = vk.VK_STRUCTURE_TYPE_DESCRIPTOR_SET_LAYOUT_CREATE_INFO,
        .bindingCount = bindings.len,
        .pBindings = &bindings,
        .pNext = null,
        .flags = 0,
    };

    try vkcheck(vk.vkCreateDescriptorSetLayout.?(vkState.logicalDevice, &layoutInfo, null, &vkState.descriptorSetLayout), "failed vkCreateDescriptorSetLayout createDescriptorSetLayout");
}

fn createColorResources(vkState: *VkState) !void {
    const colorFormat: vk.VkFormat = vkState.swapchainInfo.format.format;

    try createImage(
        vkState.swapchainInfo.extent.width,
        vkState.swapchainInfo.extent.height,
        1,
        vkState.msaaSamples,
        colorFormat,
        vk.VK_IMAGE_TILING_OPTIMAL,
        vk.VK_IMAGE_USAGE_TRANSIENT_ATTACHMENT_BIT | vk.VK_IMAGE_USAGE_COLOR_ATTACHMENT_BIT,
        vk.VK_MEMORY_PROPERTY_DEVICE_LOCAL_BIT,
        &vkState.color.image,
        &vkState.color.imageMemory,
        vkState,
    );
    vkState.color.imageView = try createImageView(vkState.color.image, colorFormat, 1, vk.VK_IMAGE_ASPECT_COLOR_BIT, vkState);
}

fn createDepthResources(vkState: *VkState, allocator: std.mem.Allocator) !void {
    const depthFormat: vk.VkFormat = try findDepthFormat(vkState, allocator);
    try createImage(
        vkState.swapchainInfo.extent.width,
        vkState.swapchainInfo.extent.height,
        1,
        vkState.msaaSamples,
        depthFormat,
        vk.VK_IMAGE_TILING_OPTIMAL,
        vk.VK_IMAGE_USAGE_DEPTH_STENCIL_ATTACHMENT_BIT,
        vk.VK_MEMORY_PROPERTY_DEVICE_LOCAL_BIT,
        &vkState.depth.image,
        &vkState.depth.imageMemory,
        vkState,
    );
    vkState.depth.imageView = try createImageView(vkState.depth.image, depthFormat, 1, vk.VK_IMAGE_ASPECT_DEPTH_BIT, vkState);
}

fn createFramebuffers(vkState: *VkState, allocator: std.mem.Allocator) !void {
    vkState.framebuffers = try allocator.alloc(vk.VkFramebuffer, vkState.swapchainImageviews.len);

    for (vkState.swapchainImageviews, 0..) |imageView, i| {
        var attachments = [_]vk.VkImageView{ vkState.color.imageView, vkState.depth.imageView, imageView };
        var framebufferInfo = vk.VkFramebufferCreateInfo{
            .sType = vk.VK_STRUCTURE_TYPE_FRAMEBUFFER_CREATE_INFO,
            .renderPass = vkState.renderPass,
            .attachmentCount = attachments.len,
            .pAttachments = &attachments,
            .width = vkState.swapchainInfo.extent.width,
            .height = vkState.swapchainInfo.extent.height,
            .layers = 1,
        };
        try vkcheck(vk.vkCreateFramebuffer.?(vkState.logicalDevice, &framebufferInfo, null, &vkState.framebuffers.?[i]), "Failed to create Framebuffer.");
    }
}

fn createCommandPool(vkState: *VkState, allocator: std.mem.Allocator) !void {
    const queueFamilyIndices = try findQueueFamilies(vkState.physicalDevice, vkState, allocator);
    var poolInfo = vk.VkCommandPoolCreateInfo{
        .sType = vk.VK_STRUCTURE_TYPE_COMMAND_POOL_CREATE_INFO,
        .flags = vk.VK_COMMAND_POOL_CREATE_RESET_COMMAND_BUFFER_BIT,
        .queueFamilyIndex = queueFamilyIndices.graphicsFamily.?,
    };
    try vkcheck(vk.vkCreateCommandPool.?(vkState.logicalDevice, &poolInfo, null, &vkState.commandPool), "Failed to create Command Pool.");
}

fn createTextureSampler(vkState: *VkState) !void {
    var properties: vk.VkPhysicalDeviceProperties = undefined;
    vk.vkGetPhysicalDeviceProperties.?(vkState.physicalDevice, &properties);
    const samplerInfo: vk.VkSamplerCreateInfo = .{
        .sType = vk.VK_STRUCTURE_TYPE_SAMPLER_CREATE_INFO,
        .magFilter = vk.VK_FILTER_LINEAR,
        .minFilter = vk.VK_FILTER_LINEAR,
        .addressModeU = vk.VK_SAMPLER_ADDRESS_MODE_CLAMP_TO_BORDER,
        .addressModeV = vk.VK_SAMPLER_ADDRESS_MODE_CLAMP_TO_BORDER,
        .addressModeW = vk.VK_SAMPLER_ADDRESS_MODE_CLAMP_TO_BORDER,
        .anisotropyEnable = vk.VK_TRUE,
        .maxAnisotropy = properties.limits.maxSamplerAnisotropy,
        .borderColor = vk.VK_BORDER_COLOR_INT_OPAQUE_BLACK,
        .unnormalizedCoordinates = vk.VK_FALSE,
        .compareEnable = vk.VK_FALSE,
        .compareOp = vk.VK_COMPARE_OP_ALWAYS,
        .mipmapMode = vk.VK_SAMPLER_MIPMAP_MODE_LINEAR,
        .mipLodBias = 0.0,
        .minLod = 0.0,
        .maxLod = vk.VK_LOD_CLAMP_NONE,
    };
    try vkcheck(vk.vkCreateSampler.?(vkState.logicalDevice, &samplerInfo, null, &vkState.textureSampler), "failed vkCreateSampler");
}

fn createVertexBuffer(vkState: *VkState, allocator: std.mem.Allocator) !void {
    const verticeData = &vkState.verticeData;
    verticeData.triangles.vertexBufferCleanUp = try allocator.alloc(?vk.VkBuffer, VkState.MAX_FRAMES_IN_FLIGHT);
    verticeData.triangles.vertexBufferMemoryCleanUp = try allocator.alloc(?vk.VkDeviceMemory, VkState.MAX_FRAMES_IN_FLIGHT);
    verticeData.lines.vertexBufferCleanUp = try allocator.alloc(?vk.VkBuffer, VkState.MAX_FRAMES_IN_FLIGHT);
    verticeData.lines.vertexBufferMemoryCleanUp = try allocator.alloc(?vk.VkDeviceMemory, VkState.MAX_FRAMES_IN_FLIGHT);
    verticeData.sprites.vertexBufferCleanUp = try allocator.alloc(?vk.VkBuffer, VkState.MAX_FRAMES_IN_FLIGHT);
    verticeData.sprites.vertexBufferMemoryCleanUp = try allocator.alloc(?vk.VkDeviceMemory, VkState.MAX_FRAMES_IN_FLIGHT);
    verticeData.spritesComplex.vertexBufferCleanUp = try allocator.alloc(?vk.VkBuffer, VkState.MAX_FRAMES_IN_FLIGHT);
    verticeData.spritesComplex.vertexBufferMemoryCleanUp = try allocator.alloc(?vk.VkDeviceMemory, VkState.MAX_FRAMES_IN_FLIGHT);
    verticeData.font.vertexBufferCleanUp = try allocator.alloc(?vk.VkBuffer, VkState.MAX_FRAMES_IN_FLIGHT);
    verticeData.font.vertexBufferMemoryCleanUp = try allocator.alloc(?vk.VkDeviceMemory, VkState.MAX_FRAMES_IN_FLIGHT);
    for (0..VkState.MAX_FRAMES_IN_FLIGHT) |i| {
        verticeData.triangles.vertexBufferCleanUp[i] = null;
        verticeData.triangles.vertexBufferMemoryCleanUp[i] = null;
        verticeData.lines.vertexBufferCleanUp[i] = null;
        verticeData.lines.vertexBufferMemoryCleanUp[i] = null;
        verticeData.sprites.vertexBufferCleanUp[i] = null;
        verticeData.sprites.vertexBufferMemoryCleanUp[i] = null;
        verticeData.spritesComplex.vertexBufferCleanUp[i] = null;
        verticeData.spritesComplex.vertexBufferMemoryCleanUp[i] = null;
        verticeData.font.vertexBufferCleanUp[i] = null;
        verticeData.font.vertexBufferMemoryCleanUp[i] = null;
    }

    try createVertexBufferColored(vkState, &verticeData.triangles, DEFAULT_VERTEX_BUFFER_INITIAL_SIZE * 3, allocator);
    try createVertexBufferColored(vkState, &verticeData.lines, DEFAULT_VERTEX_BUFFER_INITIAL_SIZE * 2, allocator);
    try createVertexBufferSprites(vkState, &verticeData.sprites, DEFAULT_VERTEX_BUFFER_INITIAL_SIZE, allocator);
    try createVertexBufferSpritesComplex(vkState, &verticeData.spritesComplex, DEFAULT_VERTEX_BUFFER_INITIAL_SIZE * 6, allocator);
    try createVertexBufferSpritesFont(vkState, &verticeData.font, DEFAULT_VERTEX_BUFFER_INITIAL_SIZE, allocator);
    verticeData.dataDrawCut = std.ArrayList(dataVulkanZig.VkVerticeDataCut).init(allocator);
}

pub fn createVertexBufferColored(vkState: *VkState, colored: *dataVulkanZig.VkColoredVertexes, size: usize, allocator: std.mem.Allocator) !void {
    if (colored.verticeCount != 0) allocator.free(colored.vertices);
    colored.vertices = try allocator.alloc(dataVulkanZig.ColoredVertex, size);
    try createBuffer(
        @sizeOf(dataVulkanZig.ColoredVertex) * colored.vertices.len,
        vk.VK_BUFFER_USAGE_VERTEX_BUFFER_BIT,
        vk.VK_MEMORY_PROPERTY_HOST_VISIBLE_BIT | vk.VK_MEMORY_PROPERTY_HOST_COHERENT_BIT,
        &colored.vertexBuffer,
        &colored.vertexBufferMemory,
        vkState,
    );
}

pub fn createVertexBufferSprites(vkState: *VkState, sprites: *dataVulkanZig.VkSprites, size: usize, allocator: std.mem.Allocator) !void {
    if (sprites.verticeCount != 0) allocator.free(sprites.vertices);
    sprites.vertices = try allocator.alloc(dataVulkanZig.SpriteVertex, size);
    try createBuffer(
        @sizeOf(dataVulkanZig.SpriteVertex) * sprites.vertices.len,
        vk.VK_BUFFER_USAGE_VERTEX_BUFFER_BIT,
        vk.VK_MEMORY_PROPERTY_HOST_VISIBLE_BIT | vk.VK_MEMORY_PROPERTY_HOST_COHERENT_BIT,
        &sprites.vertexBuffer,
        &sprites.vertexBufferMemory,
        vkState,
    );
}

pub fn createVertexBufferSpritesComplex(vkState: *VkState, spritesComplex: *dataVulkanZig.VkSpriteComplex, size: usize, allocator: std.mem.Allocator) !void {
    if (spritesComplex.verticeCount != 0) allocator.free(spritesComplex.vertices);
    spritesComplex.vertices = try allocator.alloc(dataVulkanZig.SpriteComplexVertex, size);
    try createBuffer(
        @sizeOf(dataVulkanZig.SpriteComplexVertex) * spritesComplex.vertices.len,
        vk.VK_BUFFER_USAGE_VERTEX_BUFFER_BIT,
        vk.VK_MEMORY_PROPERTY_HOST_VISIBLE_BIT | vk.VK_MEMORY_PROPERTY_HOST_COHERENT_BIT,
        &spritesComplex.vertexBuffer,
        &spritesComplex.vertexBufferMemory,
        vkState,
    );
}

pub fn createVertexBufferSpritesFont(vkState: *VkState, font: *dataVulkanZig.VkFont, size: usize, allocator: std.mem.Allocator) !void {
    if (font.verticeCount != 0) allocator.free(font.vertices);
    font.vertices = try allocator.alloc(dataVulkanZig.FontVertex, size);
    try createBuffer(
        @sizeOf(dataVulkanZig.FontVertex) * font.vertices.len,
        vk.VK_BUFFER_USAGE_VERTEX_BUFFER_BIT,
        vk.VK_MEMORY_PROPERTY_HOST_VISIBLE_BIT | vk.VK_MEMORY_PROPERTY_HOST_COHERENT_BIT,
        &font.vertexBuffer,
        &font.vertexBufferMemory,
        vkState,
    );
}

fn createUniformBuffers(vkState: *VkState, allocator: std.mem.Allocator) !void {
    const bufferSize: vk.VkDeviceSize = @sizeOf(dataVulkanZig.VkCameraData);

    vkState.uniformBuffers = try allocator.alloc(vk.VkBuffer, VkState.MAX_FRAMES_IN_FLIGHT);
    vkState.uniformBuffersMemory = try allocator.alloc(vk.VkDeviceMemory, VkState.MAX_FRAMES_IN_FLIGHT);
    vkState.uniformBuffersMapped = try allocator.alloc(?*anyopaque, VkState.MAX_FRAMES_IN_FLIGHT);

    for (0..VkState.MAX_FRAMES_IN_FLIGHT) |i| {
        try createBuffer(
            bufferSize,
            vk.VK_BUFFER_USAGE_UNIFORM_BUFFER_BIT,
            vk.VK_MEMORY_PROPERTY_HOST_VISIBLE_BIT | vk.VK_MEMORY_PROPERTY_HOST_COHERENT_BIT,
            &vkState.uniformBuffers[i],
            &vkState.uniformBuffersMemory[i],
            vkState,
        );
        try vkcheck(vk.vkMapMemory.?(vkState.logicalDevice, vkState.uniformBuffersMemory[i], 0, bufferSize, 0, &vkState.uniformBuffersMapped[i]), "failed vkMapMemory createUniformBuffers");
    }
}

fn createDescriptorPool(vkState: *VkState) !void {
    const poolSizes = [_]vk.VkDescriptorPoolSize{
        .{
            .type = vk.VK_DESCRIPTOR_TYPE_UNIFORM_BUFFER,
            .descriptorCount = VkState.MAX_FRAMES_IN_FLIGHT,
        },
        .{
            .type = vk.VK_DESCRIPTOR_TYPE_COMBINED_IMAGE_SAMPLER,
            .descriptorCount = (imageZig.IMAGE_DATA.len + 1) * VkState.MAX_FRAMES_IN_FLIGHT,
        },
    };

    const poolInfo: vk.VkDescriptorPoolCreateInfo = .{
        .sType = vk.VK_STRUCTURE_TYPE_DESCRIPTOR_POOL_CREATE_INFO,
        .poolSizeCount = poolSizes.len,
        .pPoolSizes = &poolSizes,
        .maxSets = VkState.MAX_FRAMES_IN_FLIGHT,
    };
    try vkcheck(vk.vkCreateDescriptorPool.?(vkState.logicalDevice, &poolInfo, null, &vkState.descriptorPool), "failed vkCreateDescriptorPool createDescriptorPool");
}

fn createDescriptorSets(vkState: *VkState, allocator: std.mem.Allocator) !void {
    const layouts = [_]vk.VkDescriptorSetLayout{vkState.descriptorSetLayout} ** VkState.MAX_FRAMES_IN_FLIGHT;
    const allocInfo: vk.VkDescriptorSetAllocateInfo = .{
        .sType = vk.VK_STRUCTURE_TYPE_DESCRIPTOR_SET_ALLOCATE_INFO,
        .descriptorPool = vkState.descriptorPool,
        .descriptorSetCount = VkState.MAX_FRAMES_IN_FLIGHT,
        .pSetLayouts = &layouts,
    };
    vkState.descriptorSets = try allocator.alloc(vk.VkDescriptorSet, VkState.MAX_FRAMES_IN_FLIGHT);
    try vkcheck(vk.vkAllocateDescriptorSets.?(vkState.logicalDevice, &allocInfo, @ptrCast(vkState.descriptorSets)), "failed vkAllocateDescriptorSets createDescriptorSets");

    for (0..VkState.MAX_FRAMES_IN_FLIGHT) |i| {
        const bufferInfo: vk.VkDescriptorBufferInfo = .{
            .buffer = vkState.uniformBuffers[i],
            .offset = 0,
            .range = @sizeOf(dataVulkanZig.VkCameraData),
        };

        const imageInfo: []vk.VkDescriptorImageInfo = try allocator.alloc(vk.VkDescriptorImageInfo, imageZig.IMAGE_DATA.len);
        defer allocator.free(imageInfo);
        for (0..imageZig.IMAGE_DATA.len) |j| {
            imageInfo[j] = .{
                .imageLayout = vk.VK_IMAGE_LAYOUT_SHADER_READ_ONLY_OPTIMAL,
                .imageView = vkState.spriteImages.textureImageView[j],
                .sampler = vkState.textureSampler,
            };
        }

        const imageInfoFont: vk.VkDescriptorImageInfo = .{
            .imageLayout = vk.VK_IMAGE_LAYOUT_SHADER_READ_ONLY_OPTIMAL,
            .imageView = vkState.font.textureImageView,
            .sampler = vkState.textureSampler,
        };

        const descriptorWrites = [_]vk.VkWriteDescriptorSet{
            .{
                .sType = vk.VK_STRUCTURE_TYPE_WRITE_DESCRIPTOR_SET,
                .dstSet = vkState.descriptorSets[i],
                .dstBinding = 0,
                .dstArrayElement = 0,
                .descriptorType = vk.VK_DESCRIPTOR_TYPE_UNIFORM_BUFFER,
                .descriptorCount = 1,
                .pBufferInfo = &bufferInfo,
                .pImageInfo = null,
                .pTexelBufferView = null,
            },
            .{
                .sType = vk.VK_STRUCTURE_TYPE_WRITE_DESCRIPTOR_SET,
                .dstSet = vkState.descriptorSets[i],
                .dstBinding = 1,
                .dstArrayElement = 0,
                .descriptorType = vk.VK_DESCRIPTOR_TYPE_COMBINED_IMAGE_SAMPLER,
                .descriptorCount = @as(u32, @intCast(imageInfo.len)),
                .pImageInfo = @ptrCast(imageInfo),
            },
            .{
                .sType = vk.VK_STRUCTURE_TYPE_WRITE_DESCRIPTOR_SET,
                .dstSet = vkState.descriptorSets[i],
                .dstBinding = 2,
                .dstArrayElement = 0,
                .descriptorType = vk.VK_DESCRIPTOR_TYPE_COMBINED_IMAGE_SAMPLER,
                .descriptorCount = 1,
                .pImageInfo = @ptrCast(&imageInfoFont),
            },
        };
        vk.vkUpdateDescriptorSets.?(vkState.logicalDevice, descriptorWrites.len, &descriptorWrites, 0, null);
    }
}

fn createCommandBuffers(vkState: *VkState, allocator: std.mem.Allocator) !void {
    vkState.commandBuffer = try allocator.alloc(vk.VkCommandBuffer, VkState.MAX_FRAMES_IN_FLIGHT);

    var allocInfo = vk.VkCommandBufferAllocateInfo{
        .sType = vk.VK_STRUCTURE_TYPE_COMMAND_BUFFER_ALLOCATE_INFO,
        .commandPool = vkState.commandPool,
        .level = vk.VK_COMMAND_BUFFER_LEVEL_PRIMARY,
        .commandBufferCount = @intCast(vkState.commandBuffer.len),
    };
    try vkcheck(vk.vkAllocateCommandBuffers.?(vkState.logicalDevice, &allocInfo, &vkState.commandBuffer[0]), "Failed to create Command Pool.");
}

fn createSyncObjects(vkState: *VkState, allocator: std.mem.Allocator) !void {
    var semaphoreInfo = vk.VkSemaphoreCreateInfo{
        .sType = vk.VK_STRUCTURE_TYPE_SEMAPHORE_CREATE_INFO,
    };
    var fenceInfo = vk.VkFenceCreateInfo{
        .sType = vk.VK_STRUCTURE_TYPE_FENCE_CREATE_INFO,
        .flags = vk.VK_FENCE_CREATE_SIGNALED_BIT,
    };
    vkState.imageAvailableSemaphore = try allocator.alloc(vk.VkSemaphore, VkState.MAX_FRAMES_IN_FLIGHT);
    vkState.submitSemaphores = try allocator.alloc(vk.VkSemaphore, vkState.swapchainInfo.images.len);
    vkState.inFlightFence = try allocator.alloc(vk.VkFence, VkState.MAX_FRAMES_IN_FLIGHT);

    for (0..VkState.MAX_FRAMES_IN_FLIGHT) |i| {
        if (vk.vkCreateSemaphore.?(vkState.logicalDevice, &semaphoreInfo, null, &vkState.imageAvailableSemaphore[i]) != vk.VK_SUCCESS or
            vk.vkCreateFence.?(vkState.logicalDevice, &fenceInfo, null, &vkState.inFlightFence[i]) != vk.VK_SUCCESS)
        {
            std.debug.print("Failed to Create Semaphore or Create Fence.\n", .{});
            return error.FailedToCreateSyncObjects;
        }
    }
    for (0..vkState.submitSemaphores.len) |i| {
        if (vk.vkCreateSemaphore.?(vkState.logicalDevice, &semaphoreInfo, null, &vkState.submitSemaphores[i]) != vk.VK_SUCCESS) {
            std.debug.print("Failed to Create submit Semaphore .\n", .{});
            return error.FailedToCreateSyncObjects2;
        }
    }
}

fn isDeviceSuitable(device: vk.VkPhysicalDevice, vkState: *VkState, allocator: std.mem.Allocator) !u32 {
    const indices: QueueFamilyIndices = try findQueueFamilies(device, vkState, allocator);
    vkState.graphicsQueueFamilyIdx = indices.graphicsFamily.?;

    var supportedFeatures: vk.VkPhysicalDeviceFeatures = undefined;
    vk.vkGetPhysicalDeviceFeatures.?(device, &supportedFeatures);

    const suitable = indices.isComplete() and supportedFeatures.samplerAnisotropy != 0 and
        supportedFeatures.geometryShader != 0 and supportedFeatures.fillModeNonSolid != 0;
    if (!suitable) return 0;

    var supportedFeatures2: vk.VkPhysicalDeviceFeatures2 = .{
        .sType = vk.VK_STRUCTURE_TYPE_PHYSICAL_DEVICE_FEATURES_2,
    };
    var supportedVulkan12Features: vk.VkPhysicalDeviceVulkan12Features = .{
        .sType = vk.VK_STRUCTURE_TYPE_PHYSICAL_DEVICE_VULKAN_1_2_FEATURES,
    };
    supportedFeatures2.pNext = &supportedVulkan12Features;
    vk.vkGetPhysicalDeviceFeatures2.?(device, &supportedFeatures2);
    const suitable2 = supportedVulkan12Features.shaderSampledImageArrayNonUniformIndexing != 0 and supportedVulkan12Features.runtimeDescriptorArray != 0;
    if (!suitable2) return 0;

    var score: u32 = 0;
    var physicalDeviceProperties: vk.VkPhysicalDeviceProperties = undefined;
    vk.vkGetPhysicalDeviceProperties.?(device, &physicalDeviceProperties);
    if (physicalDeviceProperties.deviceType == vk.VK_PHYSICAL_DEVICE_TYPE_DISCRETE_GPU) score += 1000;
    score += physicalDeviceProperties.limits.maxImageDimension2D;

    const counts: vk.VkSampleCountFlags = physicalDeviceProperties.limits.framebufferColorSampleCounts & physicalDeviceProperties.limits.framebufferDepthSampleCounts;
    score += counts * 16;

    return score;
}

fn findQueueFamilies(device: vk.VkPhysicalDevice, vkState: *VkState, allocator: std.mem.Allocator) !QueueFamilyIndices {
    var indices = QueueFamilyIndices{
        .graphicsFamily = null,
        .presentFamily = null,
    };
    var queueFamilyCount: u32 = 0;
    vk.vkGetPhysicalDeviceQueueFamilyProperties.?(device, &queueFamilyCount, null);

    const queueFamilies = try allocator.alloc(vk.VkQueueFamilyProperties, queueFamilyCount);
    defer allocator.free(queueFamilies);
    vk.vkGetPhysicalDeviceQueueFamilyProperties.?(device, &queueFamilyCount, queueFamilies.ptr);

    for (queueFamilies, 0..) |queueFamily, i| {
        if (queueFamily.queueFlags & vk.VK_QUEUE_GRAPHICS_BIT != 0) {
            indices.graphicsFamily = @intCast(i);
        }
        var presentSupport: vk.VkBool32 = vk.VK_FALSE;
        try vkcheck(vk.vkGetPhysicalDeviceSurfaceSupportKHR.?(device, @intCast(i), vkState.surface, &presentSupport), "failed vkGetPhysicalDeviceSurfaceSupportKHR findQueueFamilies");
        if (presentSupport == vk.VK_TRUE) {
            indices.presentFamily = @intCast(i);
        }
        if (indices.isComplete()) {
            break;
        }
    }
    return indices;
}

fn getMaxUsableSampleCount(physicalDevice: vk.VkPhysicalDevice) vk.VkSampleCountFlagBits {
    var physicalDeviceProperties: vk.VkPhysicalDeviceProperties = undefined;
    vk.vkGetPhysicalDeviceProperties.?(physicalDevice, &physicalDeviceProperties);
    std.debug.print("Graphics Card Selected: {s}\n", .{physicalDeviceProperties.deviceName});

    const counts: vk.VkSampleCountFlags = physicalDeviceProperties.limits.framebufferColorSampleCounts & physicalDeviceProperties.limits.framebufferDepthSampleCounts;
    if ((counts & vk.VK_SAMPLE_COUNT_64_BIT) != 0) {
        return vk.VK_SAMPLE_COUNT_64_BIT;
    }
    if ((counts & vk.VK_SAMPLE_COUNT_32_BIT) != 0) {
        return vk.VK_SAMPLE_COUNT_32_BIT;
    }
    if ((counts & vk.VK_SAMPLE_COUNT_16_BIT) != 0) {
        return vk.VK_SAMPLE_COUNT_16_BIT;
    }
    if ((counts & vk.VK_SAMPLE_COUNT_8_BIT) != 0) {
        return vk.VK_SAMPLE_COUNT_8_BIT;
    }
    if ((counts & vk.VK_SAMPLE_COUNT_4_BIT) != 0) {
        return vk.VK_SAMPLE_COUNT_4_BIT;
    }
    if ((counts & vk.VK_SAMPLE_COUNT_2_BIT) != 0) {
        return vk.VK_SAMPLE_COUNT_2_BIT;
    }

    return vk.VK_SAMPLE_COUNT_1_BIT;
}

fn querySwapChainSupport(vkState: *VkState, allocator: std.mem.Allocator) !SwapChainSupportDetails {
    var details = SwapChainSupportDetails{
        .capabilities = undefined,
        .formats = &.{},
        .presentModes = &.{},
    };

    var formatCount: u32 = 0;
    var presentModeCount: u32 = 0;
    try vkcheck(vk.vkGetPhysicalDeviceSurfaceCapabilitiesKHR.?(vkState.physicalDevice, vkState.surface, &details.capabilities), "failed vkGetPhysicalDeviceSurfaceCapabilitiesKHR querySwapChainSupport");
    try vkcheck(vk.vkGetPhysicalDeviceSurfaceFormatsKHR.?(vkState.physicalDevice, vkState.surface, &formatCount, null), "failed vkGetPhysicalDeviceSurfaceFormatsKHR querySwapChainSupport");
    if (formatCount > 0) {
        details.formats = try allocator.alloc(vk.VkSurfaceFormatKHR, formatCount);
        try vkcheck(vk.vkGetPhysicalDeviceSurfaceFormatsKHR.?(vkState.physicalDevice, vkState.surface, &formatCount, details.formats.ptr), "failed vkGetPhysicalDeviceSurfaceFormatsKHR2 querySwapChainSupport");
    }
    try vkcheck(vk.vkGetPhysicalDeviceSurfacePresentModesKHR.?(vkState.physicalDevice, vkState.surface, &presentModeCount, null), "failed vkGetPhysicalDeviceSurfacePresentModesKHR querySwapChainSupport");
    if (presentModeCount > 0) {
        details.presentModes = try allocator.alloc(vk.VkPresentModeKHR, presentModeCount);
        try vkcheck(vk.vkGetPhysicalDeviceSurfacePresentModesKHR.?(vkState.physicalDevice, vkState.surface, &presentModeCount, details.presentModes.ptr), "failed vkGetPhysicalDeviceSurfacePresentModesKHR2 querySwapChainSupport");
    }
    return details;
}

fn chooseSwapSurfaceFormat(formats: []const vk.VkSurfaceFormatKHR) vk.VkSurfaceFormatKHR {
    for (formats) |format| {
        if (format.format == vk.VK_FORMAT_B8G8R8A8_SRGB and format.colorSpace == vk.VK_COLOR_SPACE_SRGB_NONLINEAR_KHR) {
            return format;
        }
    }
    return formats[0];
}

fn chooseSwapPresentMode(present_modes: []const vk.VkPresentModeKHR) vk.VkPresentModeKHR {
    for (present_modes) |mode| {
        if (mode == vk.VK_PRESENT_MODE_MAILBOX_KHR) {
            return mode;
        }
    }
    return vk.VK_PRESENT_MODE_FIFO_KHR;
}

fn chooseSwapExtent(capabilities: vk.VkSurfaceCapabilitiesKHR, state: *main.GameState) vk.VkExtent2D {
    if (capabilities.currentExtent.width != std.math.maxInt(u32)) {
        return capabilities.currentExtent;
    } else {
        var width: u32 = 0;
        var height: u32 = 0;
        windowSdlZig.getWindowSize(&width, &height, state);
        var actual_extent = vk.VkExtent2D{
            .width = width,
            .height = height,
        };
        actual_extent.width = std.math.clamp(actual_extent.width, capabilities.minImageExtent.width, capabilities.maxImageExtent.width);
        actual_extent.height = std.math.clamp(actual_extent.height, capabilities.minImageExtent.height, capabilities.maxImageExtent.height);
        return actual_extent;
    }
}

pub fn createImageView(image: vk.VkImage, format: vk.VkFormat, mipLevels: u32, aspectFlags: vk.VkImageAspectFlags, vkState: *VkState) !vk.VkImageView {
    const viewInfo: vk.VkImageViewCreateInfo = .{
        .sType = vk.VK_STRUCTURE_TYPE_IMAGE_VIEW_CREATE_INFO,
        .image = image,
        .viewType = vk.VK_IMAGE_VIEW_TYPE_2D,
        .format = format,
        .subresourceRange = .{
            .aspectMask = aspectFlags,
            .baseMipLevel = 0,
            .levelCount = mipLevels,
            .baseArrayLayer = 0,
            .layerCount = 1,
        },
    };

    var imageView: vk.VkImageView = undefined;
    try vkcheck(vk.vkCreateImageView.?(vkState.logicalDevice, &viewInfo, null, &imageView), "failed vkCreateImageView");
    return imageView;
}

fn findSupportedFormat(candidates: []vk.VkFormat, tiling: vk.VkImageTiling, features: vk.VkFormatFeatureFlags, vkState: *VkState) !vk.VkFormat {
    for (candidates) |format| {
        var props: vk.VkFormatProperties = undefined;
        vk.vkGetPhysicalDeviceFormatProperties.?(vkState.physicalDevice, format, &props);
        if (tiling == vk.VK_IMAGE_TILING_LINEAR and (props.linearTilingFeatures & features) == features) {
            return format;
        } else if (tiling == vk.VK_IMAGE_TILING_OPTIMAL and (props.optimalTilingFeatures & features) == features) {
            return format;
        }
    }
    return error.vulkanNotSupportedFormat;
}

fn findDepthFormat(vkState: *VkState, allocator: std.mem.Allocator) !vk.VkFormat {
    const candidates: []c_uint = try allocator.alloc(c_uint, 3);
    candidates[0] = vk.VK_FORMAT_D32_SFLOAT;
    candidates[1] = vk.VK_FORMAT_D32_SFLOAT_S8_UINT;
    candidates[2] = vk.VK_FORMAT_D24_UNORM_S8_UINT;
    defer allocator.free(candidates);
    return findSupportedFormat(
        candidates,
        vk.VK_IMAGE_TILING_OPTIMAL,
        vk.VK_FORMAT_FEATURE_DEPTH_STENCIL_ATTACHMENT_BIT,
        vkState,
    );
}

pub fn createShaderModule(code: []const u8, vkState: *VkState) !vk.VkShaderModule {
    var createInfo = vk.VkShaderModuleCreateInfo{
        .sType = vk.VK_STRUCTURE_TYPE_SHADER_MODULE_CREATE_INFO,
        .codeSize = code.len,
        .pCode = @alignCast(@ptrCast(code.ptr)),
    };
    var shaderModule: vk.VkShaderModule = undefined;
    try vkcheck(vk.vkCreateShaderModule.?(vkState.logicalDevice, &createInfo, null, &shaderModule), "Failed to create Shader Module.");
    return shaderModule;
}

pub fn readShaderFile(filename: []const u8, allocator: std.mem.Allocator) ![]u8 {
    const code = try std.fs.cwd().readFileAlloc(allocator, filename, std.math.maxInt(usize));
    return code;
}

pub fn createImage(width: u32, height: u32, mipLevels: u32, numSamples: vk.VkSampleCountFlagBits, format: vk.VkFormat, tiling: vk.VkImageTiling, usage: vk.VkImageUsageFlags, properties: vk.VkMemoryPropertyFlags, image: *vk.VkImage, imageMemory: *vk.VkDeviceMemory, vkState: *VkState) !void {
    const imageInfo: vk.VkImageCreateInfo = .{
        .sType = vk.VK_STRUCTURE_TYPE_IMAGE_CREATE_INFO,
        .imageType = vk.VK_IMAGE_TYPE_2D,
        .extent = .{
            .width = width,
            .height = height,
            .depth = 1,
        },
        .mipLevels = mipLevels,
        .arrayLayers = 1,
        .format = format,
        .tiling = tiling,
        .initialLayout = vk.VK_IMAGE_LAYOUT_UNDEFINED,
        .usage = usage,
        .sharingMode = vk.VK_SHARING_MODE_EXCLUSIVE,
        .samples = numSamples,
        .flags = 0,
    };

    try vkcheck(vk.vkCreateImage.?(vkState.logicalDevice, &imageInfo, null, image), "failed vkCreateImage");

    var memRequirements: vk.VkMemoryRequirements = undefined;
    vk.vkGetImageMemoryRequirements.?(vkState.logicalDevice, image.*, &memRequirements);

    const allocInfo: vk.VkMemoryAllocateInfo = .{
        .sType = vk.VK_STRUCTURE_TYPE_MEMORY_ALLOCATE_INFO,
        .allocationSize = memRequirements.size,
        .memoryTypeIndex = try findMemoryType(memRequirements.memoryTypeBits, properties, vkState),
    };

    try vkcheck(vk.vkAllocateMemory.?(vkState.logicalDevice, &allocInfo, null, imageMemory), "failed vkAllocateMemory createImage");
    try vkcheck(vk.vkBindImageMemory.?(vkState.logicalDevice, image.*, imageMemory.*, 0), "failed vkBindImageMemory createImage");
}

fn findMemoryType(typeFilter: u32, properties: vk.VkMemoryPropertyFlags, vkState: *VkState) !u32 {
    var memProperties: vk.VkPhysicalDeviceMemoryProperties = undefined;
    vk.vkGetPhysicalDeviceMemoryProperties.?(vkState.physicalDevice, &memProperties);

    for (0..memProperties.memoryTypeCount) |i| {
        if ((typeFilter & (@as(u32, 1) << @as(u5, @intCast(i))) != 0) and (memProperties.memoryTypes[i].propertyFlags & properties) == properties) {
            return @as(u32, @intCast(i));
        }
    }
    return error.findMemoryType;
}

pub fn beginSingleTimeCommands(vkState: *VkState) !vk.VkCommandBuffer {
    const allocInfo: vk.VkCommandBufferAllocateInfo = .{
        .sType = vk.VK_STRUCTURE_TYPE_COMMAND_BUFFER_ALLOCATE_INFO,
        .level = vk.VK_COMMAND_BUFFER_LEVEL_PRIMARY,
        .commandPool = vkState.commandPool,
        .commandBufferCount = 1,
    };

    var commandBuffer: vk.VkCommandBuffer = undefined;
    try vkcheck(vk.vkAllocateCommandBuffers.?(vkState.logicalDevice, &allocInfo, &commandBuffer), "failed vkAllocateCommandBuffers beginSingleTimeCommands");

    const beginInfo: vk.VkCommandBufferBeginInfo = .{
        .sType = vk.VK_STRUCTURE_TYPE_COMMAND_BUFFER_BEGIN_INFO,
        .flags = vk.VK_COMMAND_BUFFER_USAGE_ONE_TIME_SUBMIT_BIT,
    };

    try vkcheck(vk.vkBeginCommandBuffer.?(commandBuffer, &beginInfo), "failed vkBeginCommandBuffer beginSingleTimeCommands");

    return commandBuffer;
}

pub fn endSingleTimeCommands(commandBuffer: vk.VkCommandBuffer, vkState: *VkState) !void {
    try vkcheck(vk.vkEndCommandBuffer.?(commandBuffer), "failed vkEndCommandBuffer endSingleTimeCommands");

    const submitInfo: vk.VkSubmitInfo = .{
        .sType = vk.VK_STRUCTURE_TYPE_SUBMIT_INFO,
        .commandBufferCount = 1,
        .pCommandBuffers = &commandBuffer,
    };

    try vkcheck(vk.vkQueueSubmit.?(vkState.queue, 1, &submitInfo, null), "failed vkQueueSubmit endSingleTimeCommands");
    try vkcheck(vk.vkQueueWaitIdle.?(vkState.queue), "failed vkQueueWaitIdle endSingleTimeCommands");

    vk.vkFreeCommandBuffers.?(vkState.logicalDevice, vkState.commandPool, 1, &commandBuffer);
}

pub fn createBuffer(size: vk.VkDeviceSize, usage: vk.VkBufferUsageFlags, properties: vk.VkMemoryPropertyFlags, buffer: *vk.VkBuffer, bufferMemory: *vk.VkDeviceMemory, vkState: *VkState) !void {
    const bufferInfo: vk.VkBufferCreateInfo = .{
        .sType = vk.VK_STRUCTURE_TYPE_BUFFER_CREATE_INFO,
        .size = size,
        .usage = usage,
        .sharingMode = vk.VK_SHARING_MODE_EXCLUSIVE,
    };

    if (vk.vkCreateBuffer.?(vkState.logicalDevice, &bufferInfo, null, &buffer.*) != vk.VK_SUCCESS) return error.CreateBuffer;
    var memRequirements: vk.VkMemoryRequirements = undefined;
    vk.vkGetBufferMemoryRequirements.?(vkState.logicalDevice, buffer.*, &memRequirements);

    const allocInfo: vk.VkMemoryAllocateInfo = .{
        .sType = vk.VK_STRUCTURE_TYPE_MEMORY_ALLOCATE_INFO,
        .allocationSize = memRequirements.size,
        .memoryTypeIndex = try findMemoryType(memRequirements.memoryTypeBits, properties, vkState),
    };
    if (vk.vkAllocateMemory.?(vkState.logicalDevice, &allocInfo, null, &bufferMemory.*) != vk.VK_SUCCESS) return error.allocateMemory;
    if (vk.vkBindBufferMemory.?(vkState.logicalDevice, buffer.*, bufferMemory.*, 0) != vk.VK_SUCCESS) return error.bindMemory;
}

pub fn recreateSwapChain(state: *main.GameState, allocator: std.mem.Allocator) !void {
    _ = vk.vkDeviceWaitIdle.?(state.vkState.logicalDevice);

    cleanupSwapChain(&state.vkState, allocator);
    _ = try createSwapChainRelatedStuffAndCheckWindowSize(state, allocator);
}

/// returns true if stuff exists or is created
pub fn createSwapChainRelatedStuffAndCheckWindowSize(state: *main.GameState, allocator: std.mem.Allocator) !bool {
    const vkState = &state.vkState;
    if (vkState.framebuffers == null) {
        var capabilities: vk.VkSurfaceCapabilitiesKHR = undefined;
        try vkcheck(vk.vkGetPhysicalDeviceSurfaceCapabilitiesKHR.?(vkState.physicalDevice, vkState.surface, &capabilities), "failed vkGetPhysicalDeviceSurfaceCapabilitiesKHR");
        if (capabilities.currentExtent.width == 0 or capabilities.currentExtent.height == 0) {
            return false;
        }

        if (vk.vkDeviceWaitIdle.?(state.vkState.logicalDevice) != vk.VK_SUCCESS) return false;
        try createSwapChain(vkState, state);
        try createImageViews(vkState, allocator);
        try createColorResources(vkState);
        try createDepthResources(vkState, allocator);
        try createFramebuffers(vkState, allocator);
        state.windowData.widthFloat = @floatFromInt(capabilities.currentExtent.width);
        state.windowData.heightFloat = @floatFromInt(capabilities.currentExtent.height);
        main.adjustZoom(state);
        settingsMenuVulkanZig.setupUiLocations(state);
        return true;
    }
    return true;
}

pub fn vkcheck(result: vk.VkResult, comptime err_msg: []const u8) !void {
    if (result != vk.VK_SUCCESS) {
        std.debug.print("Vulkan error {d}: {s}\n", .{ result, err_msg });
        return error.VulkanError;
    }
}
