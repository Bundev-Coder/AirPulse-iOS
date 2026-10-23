import Foundation
import VideoToolbox
import CoreMedia
import AVFoundation

public protocol H264DecoderDelegate: AnyObject {
    func decoder(_ decoder: H264Decoder, didOutputSampleBuffer sampleBuffer: CMSampleBuffer)
}

public final class H264Decoder {
    public weak var delegate: H264DecoderDelegate?

    private var formatDescription: CMVideoFormatDescription?
    private var spsData: Data?
    private var ppsData: Data?

    public init() {}

    /// Process Annex B NAL stream received from Video Channel
    public func decodeFrame(nalData: Data) {
        let nals = extractAnnexBNals(from: nalData)
        var avccBuffer = Data()

        for nal in nals {
            guard !nal.isEmpty else { continue }
            let nalType = nal[0] & 0x1F

            switch nalType {
            case 7: // SPS
                spsData = nal
            case 8: // PPS
                ppsData = nal
                buildFormatDescriptionIfReady()
            case 5, 1: // IDR or Non-IDR Slice
                // Convert to AVCC (4-byte length prefix)
                var lengthBE = UInt32(nal.count).bigEndian
                withUnsafeBytes(of: &lengthBE) { avccBuffer.append(contentsOf: $0) }
                avccBuffer.append(nal)
            default:
                break
            }
        }

        if !avccBuffer.isEmpty, let fmt = formatDescription {
            createSampleBuffer(from: avccBuffer, formatDescription: fmt)
        }
    }

    private func buildFormatDescriptionIfReady() {
        guard let sps = spsData, let pps = ppsData else { return }

        sps.withUnsafeBytes { spsBuf in
            pps.withUnsafeBytes { ppsBuf in
                guard let spsPtr = spsBuf.baseAddress?.assumingMemoryBound(to: UInt8.self),
                      let ppsPtr = ppsBuf.baseAddress?.assumingMemoryBound(to: UInt8.self) else { return }

                let parameterSetPointers = [spsPtr, ppsPtr]
                let parameterSetSizes = [sps.count, pps.count]

                var newFmt: CMFormatDescription?
                let status = CMVideoFormatDescriptionCreateFromH264ParameterSets(
                    allocator: kCFAllocatorDefault,
                    parameterSetCount: 2,
                    parameterSetPointers: parameterSetPointers,
                    parameterSetSizes: parameterSetSizes,
                    nalUnitHeaderLength: 4,
                    formatDescriptionOut: &newFmt
                )

                if status == noErr, let format = newFmt {
                    self.formatDescription = format
                } else {
                    print("Lỗi tạo CMVideoFormatDescription: \(status)")
                }
            }
        }
    }

    private func createSampleBuffer(from avccData: Data, formatDescription: CMVideoFormatDescription) {
        var blockBuffer: CMBlockBuffer?
        let length = avccData.count

        let status = CMBlockBufferCreateWithMemoryBlock(
            allocator: kCFAllocatorDefault,
            memoryBlock: nil,
            blockLength: length,
            blockAllocator: kCFAllocatorDefault,
            customBlockSource: nil,
            offsetToData: 0,
            dataLength: length,
            flags: 0,
            blockBufferOut: &blockBuffer
        )

        guard status == kCMBlockBufferNoErr, let buffer = blockBuffer else { return }

        avccData.withUnsafeBytes { rawPtr in
            if let base = rawPtr.baseAddress {
                CMBlockBufferReplaceDataBytes(
                    with: base,
                    blockBuffer: buffer,
                    offsetIntoDestination: 0,
                    dataLength: length
                )
            }
        }

        var sampleBuffer: CMSampleBuffer?
        var sampleSize = length
        var timingInfo = CMSampleTimingInfo(
            duration: CMTime.invalid,
            presentationTimeStamp: CMClockGetTime(CMClockGetHostTimeClock()),
            decodeTimeStamp: CMTime.invalid
        )

        let sbStatus = CMSampleBufferCreateReady(
            allocator: kCFAllocatorDefault,
            dataBuffer: buffer,
            formatDescription: formatDescription,
            sampleCount: 1,
            sampleTimingEntryCount: 1,
            sampleTimingArray: &timingInfo,
            sampleSizeEntryCount: 1,
            sampleSizeArray: &sampleSize,
            sampleBufferOut: &sampleBuffer
        )

        if sbStatus == noErr, let sb = sampleBuffer {
            delegate?.decoder(self, didOutputSampleBuffer: sb)
        }
    }

    private func extractAnnexBNals(from data: Data) -> [Data] {
        var nals: [Data] = []
        var index = 0
        let count = data.count
        var lastStart = -1

        while index < count - 3 {
            if data[index] == 0 && data[index + 1] == 0 {
                if data[index + 2] == 1 { // 3-byte start code
                    if lastStart >= 0 {
                        nals.append(data.subdata(in: lastStart..<index))
                    }
                    lastStart = index + 3
                    index += 3
                    continue
                } else if data[index + 2] == 0 && index < count - 3 && data[index + 3] == 1 { // 4-byte start code
                    if lastStart >= 0 {
                        nals.append(data.subdata(in: lastStart..<index))
                    }
                    lastStart = index + 4
                    index += 4
                    continue
                }
            }
            index += 1
        }

        if lastStart >= 0 && lastStart < count {
            nals.append(data.subdata(in: lastStart..<count))
        }

        return nals
    }
}
