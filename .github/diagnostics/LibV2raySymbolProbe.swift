import Libv2ray

// --- global-function-call style vs Libv2ray-namespaced style ---
func probeFuncNamespaced() {
    Libv2ray.initCoreEnv("", "")
}
func probeFuncGlobal() {
    Libv2rayInitCoreEnv("", "")
}

// --- CoreController type spelling ---
func probeType_LibvPrefixed(_ x: Libv2rayCoreController) {}
func probeType_Stripped(_ x: CoreController) {}

// --- CoreCallbackHandler protocol spelling ---
func probeProto_LibvProtocol(_ x: Libv2rayCoreCallbackHandlerProtocol) {}
func probeProto_LibvBare(_ x: Libv2rayCoreCallbackHandler) {}
func probeProto_StrippedProtocol(_ x: CoreCallbackHandlerProtocol) {}
func probeProto_StrippedBare(_ x: CoreCallbackHandler) {}

// --- newCoreController factory spelling (return type decoupled via Any?) ---
func probeFactory_Namespaced() {
    let _: Any? = Libv2ray.newCoreController(nil)
}
func probeFactory_Global() {
    let _: Any? = Libv2rayNewCoreController(nil)
}
