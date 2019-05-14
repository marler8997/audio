/**

First Version: http://www-mmsp.ece.mcgill.ca/Documents/AudioFormats/AIFF/Docs/AIFF-1.3.pdf
Revised Version: http://www-mmsp.ece.mcgill.ca/Documents/AudioFormats/AIFF/Docs/AIFF-C.9.26.91.pdf

The revised version added the ability to specify compression.

*/
module audio.format.aiff;

import mar.aliasseq;
import mar.expect;
import mar.intfromchars : IntFromChars;
import mar.endian : BigEndianOf, toBigEndian;
import mar.c : cstring;
import mar.file : MMapResult;

import audio.log;
import audio.renderformat;

enum AiffVersion : uint
{
    aiff = 0,
    aifc1 = 0xa2805140,
}
struct AiffFile
{
    // Fields are ordered to optimize alignment
    real sampleRate;         // from COMM chunk
    short numChannels;       // from COMM chunk
    char[] compressionName;  // from COMM chunk
    size_t soundDataFileOffset;  // from SSND chunk
    uint soundDataSize;      // from SSND chunk
    uint numSampleFrames;    // from COMM chunk
    char[4] compressionType; // from COMM chunk
    AiffVersion version_;    // from either formatType or FVER
    short sampleSize;        // from COMM chunk
}

mixin ExpectMixin!("ParseAiffResult", void
    , ErrorCase!("notImplemented", "not implemented: %", string)
    , ErrorCase!("staticError", "%", string)
    , ErrorCase!("invalidFormSize", "invalid form size %, cannot fit in file of size %", uint, size_t)
    , ErrorCase!("unsupportedAifcVersion", "this version of AIFC (%) is not supported", uint)
);

// An audio sample that has already been converted to the native render format
struct Sample
{
    RenderFormat.SampleType[] array;
    ubyte channelCount;
}
mixin ExpectMixin!("LoadAiffResult",Sample
    , ErrorCase!("notImplemented", "not implemented: %", string)
    , ErrorCase!("staticError", "%", string)
    , ErrorCase!("openFileFailed", "failed to open aiff file '%'", cstring)
    , ErrorCase!("mmapFailed", "mmap of aiff file '%' failed: %", cstring, MMapResult)
    , ErrorCase!("parseFailed", "parse '%' failed: %", cstring, ParseAiffResult)
);
ParseAiffResult parseAiff(AiffFile* aiffFile, ubyte[] fileData)
{
    import mar.array : asDynamic, startsWith, acopy;
    import mar.serialize : deserializeBE;
    import mar.print : formatHex;

    if (fileData.length < 12)
        return ParseAiffResult.staticError("file is too small");
    if (!fileData.startsWith("FORM"))
        return ParseAiffResult.staticError("file does not begin with 'FORM'");
    const formSize = deserializeBE!uint(fileData.ptr + 4);
    if (formSize % 2 == 1)
        return ParseAiffResult.notImplemented("odd form chunk size");

    const formLimit = 8 + formSize;
    if (formLimit > fileData.length)
        return ParseAiffResult.invalidFormSize(formSize, fileData.length);

    //logDebug("FORM size ", formSize, " 0x", formSize.formatHex);

    const formType = fileData[8 .. 12];
    bool versionDetermined = false;
    if (formType == "AIFF")
    {
        versionDetermined = true;
        aiffFile.version_ = AiffVersion.aiff;
    }
    else if (formType != "AIFC")
        return ParseAiffResult.staticError("formType is niether 'AIFF' nor 'AIFC'");

    static struct Chunk { size_t offset; size_t size; }
    Chunk commChunk = Chunk(0);
    Chunk ssndChunk = Chunk(0);
    for (size_t offset = 12; offset < formLimit;)
    {
        if (offset + 8 > formLimit)
        {
            logError(formLimit - offset, " bytes have bee left at then end of the form");
            break;
        }
        const chunkID = fileData[offset .. offset + 4];
        offset += 4;
        const chunkSize = deserializeBE!uint(fileData.ptr + offset);
        if (chunkSize % 2 == 1)
            return ParseAiffResult.notImplemented("odd chunkSize, I think I need to pad it to get the start of the next chunk?");
        offset += 4;
        //logDebug("chunk '", chunkID, "', data from ", offset, " to ", offset + chunkSize);

        if (chunkID == "FVER") // required chunk
        {
            if (versionDetermined)
            {
                if (aiffFile.version_ == AiffVersion.aiff)
                    return ParseAiffResult.staticError("the original aiff format does not support the new FVER chunk");
                return ParseAiffResult.staticError("multiple FVER chunks");
            }

            if (chunkSize < 4)
                return ParseAiffResult.staticError("FVER chunk is too small");
            const value = deserializeBE!uint(fileData.ptr + offset);
            if (value == AiffVersion.aifc1)
                aiffFile.version_ = AiffVersion.aifc1;
            else
                return ParseAiffResult.unsupportedAifcVersion(value);
            versionDetermined = true;
        }
        else if (chunkID == "COMM")
        {
            if (commChunk.offset != 0)
                return ParseAiffResult.staticError("multiple COMM chunks");
            commChunk.offset = offset;
            commChunk.size = chunkSize;
        }
        else if (chunkID == "SSND")
        {
            if (ssndChunk.offset != 0)
                return ParseAiffResult.staticError("multiple SSND chunks");
            ssndChunk.offset = offset;
            ssndChunk.size = chunkSize;
        }
        else
        {
            //logDebug("  this is an unrecognized chunk");
            //if (versionDetermined && aiffFile.version_ == AiffVersion.aiff)
            //    return "unrecognized chunk ID, aiff does not support this";
        }

        offset += chunkSize;
        if (offset > formLimit)
            return ParseAiffResult.staticError("chunk overran the form");
    }

    if (!versionDetermined)
        return ParseAiffResult.staticError("AIFC file is missing the required FVER chunk");

    if (commChunk.offset == 0)
        return ParseAiffResult.staticError("Missing the COMM chunk");
    if (ssndChunk.offset == 0)
        return ParseAiffResult.staticError("Missing the SSND chunk");

    //
    // Parse the COMM chunk
    //
    if (aiffFile.version_ == AiffVersion.aiff)
    {
        if (commChunk.size < 18)
            return ParseAiffResult.staticError("AIFF COMM chunk too small");
    }
    else
    {
        if (commChunk.size < 22)
            return ParseAiffResult.staticError("AIFC COMM chunk too small");
    }
    aiffFile.numChannels = deserializeBE!short(fileData.ptr + commChunk.offset);
    aiffFile.numSampleFrames = deserializeBE!uint(fileData.ptr + commChunk.offset + 2);
    aiffFile.sampleSize = deserializeBE!short(fileData.ptr + commChunk.offset + 6);
    aiffFile.sampleRate = deserializeBE!real(fileData.ptr + commChunk.offset + 8);
    /*
    logDebug(aiffFile.numChannels, " channel ",
        aiffFile.sampleSize, " bit ",
        cast(float)aiffFile.sampleRate, " Hz: ",
        aiffFile.numSampleFrames, " samples");
    */
    if (aiffFile.version_ != AiffVersion.aiff)
    {
        acopy(aiffFile.compressionType.asDynamic, fileData.ptr + commChunk.offset + 18);
        //logDebug("compressionType '", aiffFile.compressionType, "'");
        const compressionNameSize = commChunk.size - 22;
        //logDebug("compressionName '", fileData[commChunk.offset + 22 .. commChunk.offset + 22 + compressionNameSize], "'");
    }

    //
    // Parse the SSND chunk
    //
    if (ssndChunk.size < 8)
        return ParseAiffResult.staticError("SSND chunk too small");
    {
        uint offset = deserializeBE!uint(fileData.ptr + ssndChunk.offset);
        uint blockSize = deserializeBE!uint(fileData.ptr + ssndChunk.offset + 4);
        if (blockSize + 8 > ssndChunk.size)
            return ParseAiffResult.staticError("SSND blockSize overran the chunk");
        aiffFile.soundDataFileOffset = ssndChunk.offset + 8 + offset;
        if (blockSize != 0)
            return ParseAiffResult.staticError("SSND non-zero blockSize not implemented");
        aiffFile.soundDataSize = ssndChunk.size - 8 - offset;
        //logDebug("SSND fileOffset=", aiffFile.soundDataFileOffset, " size=", aiffFile.soundDataSize);
    }

    return ParseAiffResult.success;
}

auto loadAiffSample(cstring filename)
{
    import mar.mem : malloc, free;
    import mar.file : OpenAccess, OpenFileOpt, tryOpenFile,
        MMapAccess, mmap;

    import audio.format : SampleKind;

    auto file = tryOpenFile(filename, OpenFileOpt(OpenAccess.readOnly));
    if (!file.isValid)
        return LoadAiffResult.openFileFailed(filename);
    // TODO: check return value of close
    scope (exit) file.close();

    auto mmapResult = mmap(file, MMapAccess.readOnly, 0, 0);
    if (mmapResult.failed)
        return LoadAiffResult.mmapFailed(filename, mmapResult);
    // TODO: check return value of close
    scope (exit) mmapResult.val.close();

    AiffFile aiffFile;
    auto parseResult = parseAiff(&aiffFile, mmapResult.val.mem);
    if (parseResult.failed)
        return LoadAiffResult.parseFailed(filename, parseResult);

    // Decompress Sound Data
    auto rawSoundData = mmapResult.val.mem[aiffFile.soundDataFileOffset .. aiffFile.soundDataSize];
    void[] decompressed;
    if (aiffFile.version_ == AiffVersion.aiff)
        decompressed = rawSoundData;
    else
    {
        return LoadAiffResult.notImplemented("decompression");
    }
    //!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!
    //!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!
    // TODO: check that dcompressed is correct size based on audio format
    //!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!
    //!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!

    // Convert to the native format
    auto convertedSize = aiffFile.numSampleFrames * aiffFile.numChannels * RenderFormat.SampleType.sizeof;
    //log("rawSize=", rawSoundData.length, " decompressedSize=", decompressed.length,
    //    " convertedSize=", convertedSize);
    auto converted = cast(RenderFormat.SampleType*)malloc(convertedSize);
    if (converted is null)
        return LoadAiffResult.staticError("out of memory");
    // Is all AIFF just PCM?
    // TODO: verify sampleRate can be casted to uint
    // TODO: verify that numChannels can be casted to ubyte
    if (RenderFormat.copyConvert(converted, decompressed.ptr, SampleKind.int_, cast(uint)aiffFile.sampleRate,
        aiffFile.numSampleFrames, cast(ubyte)aiffFile.numChannels, cast(ubyte)(aiffFile.sampleSize / 8)).failed)
    {
        return LoadAiffResult.staticError("failed to convert AIFF audio to the native audio format");
    }

    return LoadAiffResult.success(Sample(converted[0 .. convertedSize / RenderFormat.SampleType.sizeof],
        cast(ubyte)aiffFile.numChannels));
}

/+
version = LoadSamples1;
extern (C) int main(string[] args)
{
    import mar.sentinel : lit;

    version(LoadSamples1)
    {
        immutable string[60] sampleFiles = [
            "Grand Piano-F-a6-2-a6_lite.aif",
            "Grand Piano-F-as7-1-a#7_lite.aif",
            "Grand Piano-F-b1-1-b1_lite.aif",
            "Grand Piano-F-b3-1-b3_lite.aif",
            "Grand Piano-F-b4-1-b4_lite.aif",
            "Grand Piano-F-b5-1-b5_lite.aif",
            "Grand Piano-F-c3-1-c3_lite.aif",
            "Grand Piano-F-cs7-1-c#7_lite.aif",
            "Grand Piano-F-d2-1-d2_lite.aif",
            "Grand Piano-F-d6-1-d6_lite.aif",
            "Grand Piano-F-ds4-1-d#4_lite.aif",
            "Grand Piano-F-ds5-1-d#5_lite.aif",
            "Grand Piano-F-e1-1-e1_lite.aif",
            "Grand Piano-F-e3-1-e3_lite.aif",
            "Grand Piano-F-f6-1-f6_lite.aif",
            "Grand Piano-F-fs7-1-f#7_lite.aif",
            "Grand Piano-F-g2-1-g2_lite.aif",
            "Grand Piano-F-g3-1-g3_lite.aif",
            "Grand Piano-F-g4-1-g4_lite.aif",
            "Grand Piano-F-g5-1-g5_lite.aif",
            "Grand Piano-MF-a6-1-a6_lite.aif",
            "Grand Piano-MF-as7-1-a#7_lite.aif",
            "Grand Piano-MF-b1-1-b1_lite.aif",
            "Grand Piano-MF-b3-1-b3_lite.aif",
            "Grand Piano-MF-b4-1-b4_lite.aif",
            "Grand Piano-MF-b5-1-b5_lite.aif",
            "Grand Piano-MF-c3-1c3_lite.aif",
            "Grand Piano-MF-cs7-1-c#7_lite.aif",
            "Grand Piano-MF-d2-1-d2_lite.aif",
            "Grand Piano-MF-d6-1-d6_lite.aif",
            "Grand Piano-MF-ds4-1-d#4_lite.aif",
            "Grand Piano-MF-ds5-1-d#5_lite.aif",
            "Grand Piano-MF-e1-1-e1_lite.aif",
            "Grand Piano-MF-e3-1-e3_lite.aif",
            "Grand Piano-MF-f6-1-f6_lite.aif",
            "Grand Piano-MF-fs7-1-f#7_lite.aif",
            "Grand Piano-MF-g2-1-g2_lite.aif",
            "Grand Piano-MF-g3-1-g3_lite.aif",
            "Grand Piano-MF-g4-1-g4_lite.aif",
            "Grand Piano-MF-g5-1-g5_lite.aif",
            "Grand Piano-MP-a6-1-a6_lite.aif",
            "Grand Piano-MP-as7-1-a#7_lite.aif",
            "Grand Piano-MP-b1-1-b1_lite.aif",
            "Grand Piano-MP-b3-1-b3_lite.aif",
            "Grand Piano-MP-b4-1-b4_lite.aif",
            "Grand Piano-MP-b5-1-b5_lite.aif",
            "Grand Piano-MP-c3-2-c3_lite.aif",
            "Grand Piano-MP-cs7-1-c#7_lite.aif",
            "Grand Piano-MP-d2-1-d2_lite.aif",
            "Grand Piano-MP-d6-1-d6_lite.aif",
            "Grand Piano-MP-ds4-1-d#4_lite.aif",
            "Grand Piano-MP-ds5-1-d#5_lite.aif",
            "Grand Piano-MP-e1-1-e1_lite.aif",
            "Grand Piano-MP-e3-1-e3_lite.aif",
            "Grand Piano-MP-f6-1-f6_lite.aif",
            "Grand Piano-MP-fs7-1-f#7_lite.aif",
            "Grand Piano-MP-g2-1-g2_lite.aif",
            "Grand Piano-MP-g3-1-g3_lite.aif",
            "Grand Piano-MP-g4-1-g4_lite.aif",
            "Grand Piano-MP-g5-1-g5_lite.aif",
        ];
        foreach (sampleFile; sampleFiles)
        {
            import mar.mem : free;
            import mar.print : sprintMallocSentinel;
            auto fullName = sprintMallocSentinel(r"D:\git\music\ableton\Worship Project\Samples\Imported\", sampleFile);
            auto result = loadAiffSample(fullName.ptr);
            logDebug("parseResult: ", result);
            free(fullName.ptr.raw);
        }
    }

    /*
    immutable string[20] samples2 = [
        "MF-a6.aif",
        "MF-asharp7.aif",
        "MF-b1.aif",
        "MF-b3.aif",
        "MF-b4.aif",
        "MF-b5.aif",
        "MF-c3.aif",
        "MF-csharp7.aif",
        "MF-d2.aif",
        "MF-d6.aif",
        "MF-dsharp4.aif",
        "MF-dsharp5.aif",
        "MF-e1.aif",
        "MF-e3.aif",
        "MF-f6.aif",
        "MF-fsharp7.aif",
        "MF-g2.aif",
        "MF-g3.aif",
        "MF-g4.aif",
        "MF-g5.aif",
    ];
    */
    immutable string[1] samples2 = ["MF-a6.aif"];
    foreach (sampleFile; samples2)
    {
        import mar.mem : free;
        import mar.print : sprintMallocSentinel;
        auto fullName = sprintMallocSentinel(r"D:\GrandPiano\", sampleFile);
        auto result = loadAiffSample(fullName.ptr);
        logDebug("parseResult: ", result);
        free(fullName.ptr.raw);
    }
    return 0;
}
+/