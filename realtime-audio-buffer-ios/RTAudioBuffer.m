/*
 
 This is free and unencumbered software released into the public domain.
 
 Anyone is free to copy, modify, publish, use, compile, sell, or
 distribute this software, either in source code form or as a compiled
 binary, for any purpose, commercial or non-commercial, and by any
 means.
 
 In jurisdictions that recognize copyright laws, the author or authors
 of this software dedicate any and all copyright interest in the
 software to the public domain. We make this dedication for the benefit
 of the public at large and to the detriment of our heirs and
 successors. We intend this dedication to be an overt act of
 relinquishment in perpetuity of all present and future rights to this
 software under copyright law.
 
 THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND,
 EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF
 MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT.
 IN NO EVENT SHALL THE AUTHORS BE LIABLE FOR ANY CLAIM, DAMAGES OR
 OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE,
 ARISING FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR
 OTHER DEALINGS IN THE SOFTWARE.
 
 For more information, please refer to <http://unlicense.org>
 
 ----------------------------------------------------------------
 realtime-audio-buffer-ios v0.8
 Author: Harry Lundström 2017-01-22
 
 */

#import "RTAudioBuffer.h"
#import <AVFoundation/AVFoundation.h>

@implementation RTAudioBuffer
static AudioUnit *audioUnit = NULL;
static bool debuglog = true;
void printOSStatus(char *name, OSStatus status) {
    if(debuglog) {
        NSError *error = [NSError errorWithDomain:NSOSStatusErrorDomain code:status userInfo:nil];
        NSLog(@"%s:%@", name, error);
    }
}
void rtAudioInitWithCallback(OSStatus(*renderCallback)(void *userData,
                                                       AudioUnitRenderActionFlags *actionFlags,
                                                       const AudioTimeStamp *audioTimeStamp,
                                                       UInt32 busNumber,
                                                       UInt32 numFrames,
                                                       AudioBufferList *buffers),
                                                       double preferredBufferDurationInSeconds) {
    // init audio session
    BOOL success = YES;
    NSError *error;
    audioUnit = (AudioUnit*)malloc(sizeof(AudioUnit));
    success = [[AVAudioSession sharedInstance] setActive:YES error:nil];
    if(!success) {
        if(debuglog) {
            NSLog(@"setActive %@", error);
        }
        return;
    }
    success = [[AVAudioSession sharedInstance] setCategory:AVAudioSessionCategoryPlayback error:nil];
    if(!success) {
        if(debuglog) {
            NSLog(@"AVAudioSessionCategoryPlayback %@", error);
        }
        return;
    }
    success = [[AVAudioSession sharedInstance] setPreferredIOBufferDuration:preferredBufferDurationInSeconds error:&error];
    if(!success) {
        if(debuglog) {
            NSLog(@"setPreferredIOBufferDuration %@", error);
        }
        return;
    }
    // init audio streams
    OSStatus status = noErr;
    AudioComponentDescription componentDescription;
    componentDescription.componentType = kAudioUnitType_Output;
    componentDescription.componentSubType = kAudioUnitSubType_RemoteIO;
    componentDescription.componentManufacturer = kAudioUnitManufacturer_Apple;
    componentDescription.componentFlags = 0;
    componentDescription.componentFlagsMask = 0;
    AudioComponent component = AudioComponentFindNext(NULL, &componentDescription);
    status = AudioComponentInstanceNew(component, audioUnit);
    if(status != noErr) {
        printOSStatus("AudioComponentInstanceNew", status);
        return;
    }
    // the stream will be set up as a 16bit signed integer interleaved stereo PCM.
    AudioStreamBasicDescription streamDescription;
    streamDescription.mSampleRate = 44100;
    streamDescription.mFormatID = kAudioFormatLinearPCM;
    streamDescription.mFormatFlags = kAudioFormatFlagIsSignedInteger | kAudioFormatFlagIsPacked | kAudioFormatFlagsNativeEndian;
    streamDescription.mChannelsPerFrame = 2;
    streamDescription.mBytesPerPacket = sizeof(SInt16) * 2;
    streamDescription.mFramesPerPacket = 1;
    streamDescription.mBytesPerFrame = sizeof(SInt16) * 2;
    streamDescription.mBitsPerChannel = sizeof(SInt16) * 8;
    streamDescription.mReserved = 0;
    
    // input stream
    // (it's a bit confusing, but apparently it's called input because the samples we write in the callback are considered an input)
    status = AudioUnitSetProperty(*audioUnit, kAudioUnitProperty_StreamFormat,
                                  kAudioUnitScope_Input, 0, &streamDescription, sizeof(streamDescription));
    if(status != noErr) {
        printOSStatus("AudioUnitSetProperty kAudioUnitProperty_StreamFormat kAudioUnitScope_Input", status);
        return;
    }
    AURenderCallbackStruct callbackStruct;
    callbackStruct.inputProc = renderCallback; // render function
    callbackStruct.inputProcRefCon = NULL;
    status = AudioUnitSetProperty(*audioUnit, kAudioUnitProperty_SetRenderCallback,
                                  kAudioUnitScope_Input, 0, &callbackStruct,
                                  sizeof(AURenderCallbackStruct));
    if(status != noErr) {
        printOSStatus("AudioUnitSetProperty kAudioUnitProperty_SetRenderCallback", status);
        return;
    }
    rtAudioStartAudioUnit();
}
void rtAudioStartAudioUnit(void) {
    OSStatus status = noErr;
    status = AudioUnitInitialize(*audioUnit);
    if(status != noErr) {
        printOSStatus("AudioUnitInitialize", status);
    }
    status = AudioOutputUnitStart(*audioUnit);
    if(status != noErr) {
        printOSStatus("AudioOutputUnitStart", status);
    }
}
void rtAudioStopProcessingAudio(void) {
    OSStatus status = noErr;
    status = AudioOutputUnitStop(*audioUnit);
    if(status != noErr) {
        printOSStatus("AudioOutputUnitStop", status);
    }
    status = AudioUnitUninitialize(*audioUnit);
    if(status != noErr) {
        printOSStatus("AudioUnitUninitialize", status);
    }
    *audioUnit = NULL;
}
@end
