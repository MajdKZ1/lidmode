import Foundation
import CoreGraphics

// Built-in display brightness via the private DisplayServices framework.
// usage: lidmode-brightness get | set <0.0-1.0>
guard let h = dlopen("/System/Library/PrivateFrameworks/DisplayServices.framework/DisplayServices", RTLD_NOW) else {
    FileHandle.standardError.write(Data("cannot load DisplayServices\n".utf8)); exit(2)
}
typealias GetFn = @convention(c) (UInt32, UnsafeMutablePointer<Float>) -> Int32
typealias SetFn = @convention(c) (UInt32, Float) -> Int32
guard let g = dlsym(h, "DisplayServicesGetBrightness"), let s = dlsym(h, "DisplayServicesSetBrightness") else {
    FileHandle.standardError.write(Data("symbols missing\n".utf8)); exit(2)
}
let getB = unsafeBitCast(g, to: GetFn.self)
let setB = unsafeBitCast(s, to: SetFn.self)

var ids = [CGDirectDisplayID](repeating: 0, count: 16)
var n: UInt32 = 0
CGGetOnlineDisplayList(16, &ids, &n)
let builtin = ids.prefix(Int(n)).first { CGDisplayIsBuiltin($0) != 0 } ?? CGMainDisplayID()

let args = CommandLine.arguments
if args.count >= 2, args[1] == "get" {
    var v: Float = 0
    if getB(builtin, &v) != 0 { exit(1) }
    print(String(format: "%.4f", v))
} else if args.count >= 3, args[1] == "set", let v = Float(args[2]) {
    exit(setB(builtin, max(0, min(1, v))) == 0 ? 0 : 1)
} else {
    FileHandle.standardError.write(Data("usage: get | set <0-1>\n".utf8)); exit(64)
}
