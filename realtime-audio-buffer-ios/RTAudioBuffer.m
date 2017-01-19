//
//  RTAudioBuffer.m
//  ios-realtime-audio-buffer
//
//  Created by Harry Lundstrom on 18/01/17.
//  Copyright © 2017 Harry Lundström. All rights reserved.
//

/*
 todo:
    - handle routechange events
    - review all properties to set
    - clean up resources
    - correct behavious with the rest of the iOS audio system,
    - determine what needs to be done when suspending/resuming app (lifecycle)
 */

#import "RTAudioBuffer.h"
#import <AudioUnit/AudioUnit.h>
#import <AudioToolbox/AudioSession.h>
#import <AVFoundation/AVFoundation.h>

@implementation RTAudioBuffer
static AudioUnit *audioUnit = NULL;
static void initAudioSession(void);
static void initAudioStreams(void);
void runAudio(void) {
    initAudioSession();
    initAudioStreams();
    startAudioUnit();
}
void printOSStatus(char *name, OSStatus status) {
    if(status != noErr) {
        NSError *error = [NSError errorWithDomain:NSOSStatusErrorDomain code:status userInfo:nil];
        NSLog(@"%s:%@", name, error);
    }
}
static void initAudioSession(void) {
    BOOL success = YES;
    NSError *error;
    audioUnit = (AudioUnit*)malloc(sizeof(AudioUnit));
    success = [[AVAudioSession sharedInstance] setActive:YES error:nil];
    if(!success) {
        NSLog(@"setActive %@", error);
        return;
    }
    success = [[AVAudioSession sharedInstance] setCategory:AVAudioSessionCategoryPlayback error:nil];
    if(!success) {
        NSLog(@"AVAudioSessionCategoryPlayback %@", error);
        return;
    }
    success = [[AVAudioSession sharedInstance] setPreferredIOBufferDuration:0.02 error:&error];
    if(!success) {
        NSLog(@"setPreferredIOBufferDuration %@", error);
        return;
    }
   /* UInt32 overrideCategory = 1;
    if(AudioSessionSetProperty(kAudioSessionProperty_OverrideCategoryDefaultToSpeaker,
                               sizeof(UInt32), &overrideCategory) != noErr) {
        return 1;
    }*/
    
    // There are many properties you might want to provide callback functions for:
    // kAudioSessionProperty_AudioRouteChange
    // kAudioSessionProperty_OverrideCategoryEnableBluetoothInput
    // etc.
    
}
void initAudioStreams(void) {
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
    AURenderCallbackStruct callbackStruct;
    callbackStruct.inputProc = renderCallback; // Render function
    callbackStruct.inputProcRefCon = NULL;
    status = AudioUnitSetProperty(*audioUnit, kAudioUnitProperty_SetRenderCallback,
                            kAudioUnitScope_Input, 0, &callbackStruct,
                                  sizeof(AURenderCallbackStruct));
    if(status != noErr) {
        printOSStatus("AudioUnitSetProperty kAudioUnitProperty_SetRenderCallback", status);
        return;
    }
    AudioStreamBasicDescription streamDescription;
    // You might want to replace this with a different value, but keep in mind that the
    // iPhone does not support all sample rates. 8kHz, 22kHz, and 44.1kHz should all work.
    streamDescription.mSampleRate = 44100;
    // Yes, I know you probably want floating point samples, but the iPhone isn't going
    // to give you floating point data. You'll need to make the conversion by hand from
    // linear PCM <-> float.
    streamDescription.mFormatID = kAudioFormatLinearPCM;
    // This part is important!
    streamDescription.mFormatFlags = kAudioFormatFlagIsSignedInteger |
    kAudioFormatFlagsNativeEndian |
    kAudioFormatFlagIsPacked;
    // Not sure if the iPhone supports recording >16-bit audio, but I doubt it.
    streamDescription.mBitsPerChannel = 16;
    // 1 sample per frame, will always be 2 as long as 16-bit samples are being used
    streamDescription.mBytesPerFrame = 2;
    // Record in mono. Use 2 for stereo, though I don't think the iPhone does true stereo recording
    streamDescription.mChannelsPerFrame = 1;
    streamDescription.mBytesPerPacket = streamDescription.mBytesPerFrame *
    streamDescription.mChannelsPerFrame;
    // Always should be set to 1
    streamDescription.mFramesPerPacket = 1;
    // Always set to 0, just to be sure
    streamDescription.mReserved = 0;
    // Set up input stream with above properties
    status = AudioUnitSetProperty(*audioUnit, kAudioUnitProperty_StreamFormat,
                                  kAudioUnitScope_Input, 0, &streamDescription, sizeof(streamDescription));
    if(status != noErr) {
        printOSStatus("AudioUnitSetProperty kAudioUnitProperty_StreamFormat kAudioUnitScope_Input", status);
        return;
    }
    // Ditto for the output stream, which we will be sending the processed audio to
    status = AudioUnitSetProperty(*audioUnit, kAudioUnitProperty_StreamFormat,
                                  kAudioUnitScope_Output, 1, &streamDescription, sizeof(streamDescription));
    if(status != noErr) {
        printOSStatus("AudioUnitSetProperty kAudioUnitProperty_StreamFormat kAudioUnitScope_Output", status);
        return;
    }
}
void startAudioUnit(void) {
    OSStatus status = noErr;
    status = AudioUnitInitialize(*audioUnit);
    printOSStatus("AudioUnitInitialize", status);
    status = AudioOutputUnitStart(*audioUnit);
    printOSStatus("AudioOutputUnitStart", status);
}
void stopProcessingAudio(void) {
    OSStatus status = noErr;
    status = AudioOutputUnitStop(*audioUnit);
    printOSStatus("AudioOutputUnitStop", status);
    status = AudioUnitUninitialize(*audioUnit);
    printOSStatus("AudioUnitUninitialize", status);
    *audioUnit = NULL;
}
OSStatus renderCallback(void *userData,
                        AudioUnitRenderActionFlags *actionFlags,
                        const AudioTimeStamp *audioTimeStamp,
                        UInt32 busNumber,
                        UInt32 numFrames,
                        AudioBufferList *buffers) {
    SInt16 *inputFrames = (SInt16*)(buffers->mBuffers->mData);
    for(int i = 0; i < numFrames; i++) {
        inputFrames[i] = (rand() % 32767) -16000;
    }
    return noErr;
}
@end
