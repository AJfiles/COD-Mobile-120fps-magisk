// Capa Vulkan mínima: intercepta la identidad de la GPU y la presenta como
// Adreno (TM) 830 + Snapdragon 8 Elite. No usa código de terceros.
#include <vulkan/vulkan.h>
#include <vulkan/vk_layer.h>
#include <android/log.h>
#include <cstring>

#define LOG_TAG "CodmGpuSpoof"
#define LOGI(...) __android_log_print(ANDROID_LOG_INFO, LOG_TAG, __VA_ARGS__)

namespace {
constexpr const char* kLayerName = "VK_LAYER_CODM_GPU_SPOOF";
constexpr const char* kFakeName = "Adreno (TM) 830";
constexpr uint32_t kFakeVendor = 0x5143;  // Qualcomm
constexpr uint32_t kFakeDevice = 0x44050001;  // Adreno 830 / SM8750 (Qualcomm)

PFN_vkGetInstanceProcAddr g_nextGipa = nullptr;
PFN_vkGetDeviceProcAddr g_nextGdpa = nullptr;
PFN_vkGetPhysicalDeviceProperties g_nextProps = nullptr;
PFN_vkGetPhysicalDeviceProperties2 g_nextProps2 = nullptr;
PFN_vkGetPhysicalDeviceProperties2KHR g_nextProps2Khr = nullptr;
VkInstance g_instance = VK_NULL_HANDLE;
bool g_logged = false;

PFN_vkVoidFunction loadNext(const char* name) {
    if (!g_nextGipa || g_instance == VK_NULL_HANDLE) return nullptr;
    return g_nextGipa(g_instance, name);
}

void patch(VkPhysicalDeviceProperties* p) {
    if (!p) return;
    strncpy(p->deviceName, kFakeName, VK_MAX_PHYSICAL_DEVICE_NAME_SIZE - 1);
    p->deviceName[VK_MAX_PHYSICAL_DEVICE_NAME_SIZE - 1] = '\0';
    p->vendorID = kFakeVendor;
    p->deviceID = kFakeDevice;
    if (!g_logged) {
        g_logged = true;
        LOGI("identidad parcheada: %s vendor=0x%x device=0x%x", p->deviceName, p->vendorID, p->deviceID);
    }
}
}  // namespace

extern "C" {

VKAPI_ATTR VkResult VKAPI_CALL layer_CreateInstance(
        const VkInstanceCreateInfo* pCreateInfo,
        const VkAllocationCallbacks* pAllocator, VkInstance* pInstance) {
    auto* link = reinterpret_cast<const VkLayerInstanceCreateInfo*>(pCreateInfo->pNext);
    while (link) {
        if (link->sType == VK_STRUCTURE_TYPE_LOADER_INSTANCE_CREATE_INFO &&
            link->function == VK_LAYER_LINK_INFO) {
            break;
        }
        link = reinterpret_cast<const VkLayerInstanceCreateInfo*>(link->pNext);
    }
    if (!link || !link->u.pLayerInfo) return VK_ERROR_INITIALIZATION_FAILED;

    auto* mutableLink = const_cast<VkLayerInstanceCreateInfo*>(link);
    g_nextGipa = mutableLink->u.pLayerInfo->pfnNextGetInstanceProcAddr;
    mutableLink->u.pLayerInfo = mutableLink->u.pLayerInfo->pNext;

    auto nextCreate = reinterpret_cast<PFN_vkCreateInstance>(
            g_nextGipa(nullptr, "vkCreateInstance"));
    if (!nextCreate) return VK_ERROR_INITIALIZATION_FAILED;

    VkResult result = nextCreate(pCreateInfo, pAllocator, pInstance);
    if (result == VK_SUCCESS && pInstance != nullptr) {
        g_instance = *pInstance;
        g_nextProps = reinterpret_cast<PFN_vkGetPhysicalDeviceProperties>(
                loadNext("vkGetPhysicalDeviceProperties"));
        g_nextProps2 = reinterpret_cast<PFN_vkGetPhysicalDeviceProperties2>(
                loadNext("vkGetPhysicalDeviceProperties2"));
        g_nextProps2Khr = reinterpret_cast<PFN_vkGetPhysicalDeviceProperties2KHR>(
                loadNext("vkGetPhysicalDeviceProperties2KHR"));
        if (!g_nextProps2) {
            g_nextProps2 = reinterpret_cast<PFN_vkGetPhysicalDeviceProperties2>(g_nextProps2Khr);
        }
        LOGI("instancia creada; props=%p props2=%p", (void*)g_nextProps, (void*)g_nextProps2);
    }
    return result;
}

VKAPI_ATTR void VKAPI_CALL layer_DestroyInstance(
        VkInstance instance, const VkAllocationCallbacks* pAllocator) {
    if (g_nextGipa && instance != VK_NULL_HANDLE) {
        auto next = reinterpret_cast<PFN_vkDestroyInstance>(
                g_nextGipa(instance, "vkDestroyInstance"));
        if (next) next(instance, pAllocator);
    }
    if (instance == g_instance) {
        g_instance = VK_NULL_HANDLE;
        g_nextProps = nullptr;
        g_nextProps2 = nullptr;
        g_nextProps2Khr = nullptr;
        g_logged = false;
    }
}

VKAPI_ATTR void VKAPI_CALL layer_GetPhysicalDeviceProperties(
        VkPhysicalDevice physicalDevice, VkPhysicalDeviceProperties* pProperties) {
    if (!g_nextProps && g_nextGipa) {
        g_nextProps = reinterpret_cast<PFN_vkGetPhysicalDeviceProperties>(
                loadNext("vkGetPhysicalDeviceProperties"));
    }
    if (g_nextProps) g_nextProps(physicalDevice, pProperties);
    patch(pProperties);
}

VKAPI_ATTR void VKAPI_CALL layer_GetPhysicalDeviceProperties2(
        VkPhysicalDevice physicalDevice, VkPhysicalDeviceProperties2* pProperties) {
    if (!g_nextProps2 && g_nextProps2Khr) {
        g_nextProps2 = reinterpret_cast<PFN_vkGetPhysicalDeviceProperties2>(g_nextProps2Khr);
    }
    if (!g_nextProps2 && g_nextGipa) {
        g_nextProps2 = reinterpret_cast<PFN_vkGetPhysicalDeviceProperties2>(
                loadNext("vkGetPhysicalDeviceProperties2"));
    }
    if (g_nextProps2) {
        g_nextProps2(physicalDevice, pProperties);
    } else if (g_nextProps) {
        g_nextProps(physicalDevice, &pProperties->properties);
    }
    if (pProperties) patch(&pProperties->properties);
}

VKAPI_ATTR PFN_vkVoidFunction VKAPI_CALL layer_GetDeviceProcAddr(
        VkDevice device, const char* pName) {
    if (!g_nextGdpa && g_nextGipa && g_instance != VK_NULL_HANDLE) {
        g_nextGdpa = reinterpret_cast<PFN_vkGetDeviceProcAddr>(
                g_nextGipa(g_instance, "vkGetDeviceProcAddr"));
    }
    if (g_nextGdpa) return g_nextGdpa(device, pName);
    return nullptr;
}

VKAPI_ATTR PFN_vkVoidFunction VKAPI_CALL layer_GetInstanceProcAddr(
        VkInstance instance, const char* pName) {
    if (!pName) return nullptr;
    if (strcmp(pName, "vkCreateInstance") == 0) return reinterpret_cast<PFN_vkVoidFunction>(layer_CreateInstance);
    if (strcmp(pName, "vkDestroyInstance") == 0) return reinterpret_cast<PFN_vkVoidFunction>(layer_DestroyInstance);
    if (strcmp(pName, "vkGetInstanceProcAddr") == 0) return reinterpret_cast<PFN_vkVoidFunction>(layer_GetInstanceProcAddr);
    if (strcmp(pName, "vkGetDeviceProcAddr") == 0) return reinterpret_cast<PFN_vkVoidFunction>(layer_GetDeviceProcAddr);
    if (strcmp(pName, "vkEnumerateInstanceLayerProperties") == 0) return reinterpret_cast<PFN_vkVoidFunction>(vkEnumerateInstanceLayerProperties);
    if (strcmp(pName, "vkEnumerateInstanceExtensionProperties") == 0) return reinterpret_cast<PFN_vkVoidFunction>(vkEnumerateInstanceExtensionProperties);
    if (strcmp(pName, "vkGetPhysicalDeviceProperties") == 0) return reinterpret_cast<PFN_vkVoidFunction>(layer_GetPhysicalDeviceProperties);
    if (strcmp(pName, "vkGetPhysicalDeviceProperties2") == 0) return reinterpret_cast<PFN_vkVoidFunction>(layer_GetPhysicalDeviceProperties2);
    if (strcmp(pName, "vkGetPhysicalDeviceProperties2KHR") == 0) return reinterpret_cast<PFN_vkVoidFunction>(layer_GetPhysicalDeviceProperties2);
    if (g_nextGipa && instance != VK_NULL_HANDLE) return g_nextGipa(instance, pName);
    if (g_nextGipa) return g_nextGipa(nullptr, pName);
    return nullptr;
}

VKAPI_ATTR PFN_vkVoidFunction VKAPI_CALL layer_GetPhysicalDeviceProcAddr(
        VkInstance instance, const char* pName) {
    if (!pName) return nullptr;
    if (strcmp(pName, "vkGetPhysicalDeviceProperties") == 0) return reinterpret_cast<PFN_vkVoidFunction>(layer_GetPhysicalDeviceProperties);
    if (strcmp(pName, "vkGetPhysicalDeviceProperties2") == 0) return reinterpret_cast<PFN_vkVoidFunction>(layer_GetPhysicalDeviceProperties2);
    if (strcmp(pName, "vkGetPhysicalDeviceProperties2KHR") == 0) return reinterpret_cast<PFN_vkVoidFunction>(layer_GetPhysicalDeviceProperties2);
    if (g_nextGipa && instance != VK_NULL_HANDLE) {
        auto next = reinterpret_cast<PFN_GetPhysicalDeviceProcAddr>(
                g_nextGipa(instance, "vk_layerGetPhysicalDeviceProcAddr"));
        if (next) return next(instance, pName);
    }
    return nullptr;
}

VKAPI_ATTR PFN_vkVoidFunction VKAPI_CALL vkGetInstanceProcAddr(
        VkInstance instance, const char* pName) {
    return layer_GetInstanceProcAddr(instance, pName);
}

VKAPI_ATTR PFN_vkVoidFunction VKAPI_CALL vkGetDeviceProcAddr(
        VkDevice device, const char* pName) {
    return layer_GetDeviceProcAddr(device, pName);
}

VKAPI_ATTR VkResult VKAPI_CALL vkEnumerateInstanceLayerProperties(
        uint32_t* pPropertyCount, VkLayerProperties* pProperties) {
    if (!pPropertyCount) return VK_ERROR_INITIALIZATION_FAILED;
    if (!pProperties) {
        *pPropertyCount = 1;
        return VK_SUCCESS;
    }
    if (*pPropertyCount < 1) return VK_INCOMPLETE;
    memset(pProperties, 0, sizeof(*pProperties));
    strncpy(pProperties[0].layerName, kLayerName, sizeof(pProperties[0].layerName) - 1);
    pProperties[0].specVersion = VK_API_VERSION_1_1;
    pProperties[0].implementationVersion = 1;
    strncpy(pProperties[0].description, "CODM GPU identity spoof", sizeof(pProperties[0].description) - 1);
    *pPropertyCount = 1;
    return VK_SUCCESS;
}

VKAPI_ATTR VkResult VKAPI_CALL vkEnumerateInstanceExtensionProperties(
        const char* pLayerName, uint32_t* pPropertyCount,
        VkExtensionProperties* pProperties) {
    if (pLayerName && strcmp(pLayerName, kLayerName) != 0) return VK_ERROR_LAYER_NOT_PRESENT;
    if (!pPropertyCount) return VK_ERROR_INITIALIZATION_FAILED;
    *pPropertyCount = 0;
    (void)pProperties;
    return VK_SUCCESS;
}

VKAPI_ATTR VkResult VKAPI_CALL vkNegotiateLoaderLayerInterfaceVersion(
        VkNegotiateLayerInterface* pVersionStruct) {
    if (!pVersionStruct || pVersionStruct->loaderLayerInterfaceVersion < 1) {
        return VK_ERROR_INITIALIZATION_FAILED;
    }
    pVersionStruct->loaderLayerInterfaceVersion = 2;
    pVersionStruct->pfnGetInstanceProcAddr = layer_GetInstanceProcAddr;
    pVersionStruct->pfnGetDeviceProcAddr = layer_GetDeviceProcAddr;
    pVersionStruct->pfnGetPhysicalDeviceProcAddr = layer_GetPhysicalDeviceProcAddr;
    LOGI("negociacion de capa v2");
    return VK_SUCCESS;
}

}  // extern "C"
