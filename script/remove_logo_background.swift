#!/usr/bin/env swift

import CoreImage
import Foundation
import Vision

guard CommandLine.arguments.count == 3 else {
    FileHandle.standardError.write(Data("usage: remove_logo_background.swift INPUT OUTPUT\n".utf8))
    exit(2)
}

let inputURL = URL(fileURLWithPath: CommandLine.arguments[1])
let outputURL = URL(fileURLWithPath: CommandLine.arguments[2])

guard let source = CIImage(contentsOf: inputURL) else {
    throw CocoaError(.fileReadCorruptFile)
}

let request = VNGenerateForegroundInstanceMaskRequest()
let handler = VNImageRequestHandler(url: inputURL)
try handler.perform([request])

guard let observation = request.results?.first else {
    throw CocoaError(.featureUnsupported)
}

let pixelBuffer = try observation.generateScaledMaskForImage(
    forInstances: observation.allInstances,
    from: handler
)
let foregroundMask = CIImage(cvPixelBuffer: pixelBuffer)

// Vision treats the colorful mark as a foreground instance, but not the white
// wordmark beside it. A luminance threshold recovers those exact source pixels;
// the dark background stays well below the cutoff.
let wordmarkMask = source
    .applyingFilter("CIColorThreshold", parameters: ["inputThreshold": 0.42])
let mask = foregroundMask.applyingFilter(
    "CIMaximumCompositing",
    parameters: [kCIInputBackgroundImageKey: wordmarkMask]
)
let transparent = CIImage(color: .clear).cropped(to: source.extent)

guard let output = CIFilter(
    name: "CIBlendWithMask",
    parameters: [
        kCIInputImageKey: source,
        kCIInputBackgroundImageKey: transparent,
        kCIInputMaskImageKey: mask
    ]
)?.outputImage else {
    throw CocoaError(.featureUnsupported)
}

let context = CIContext(options: [.useSoftwareRenderer: false])
let colorSpace = CGColorSpace(name: CGColorSpace.sRGB)!
try context.writePNGRepresentation(
    of: output,
    to: outputURL,
    format: .RGBA8,
    colorSpace: colorSpace
)
