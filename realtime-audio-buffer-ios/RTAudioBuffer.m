//
//  RTAudioBuffer.m
//  ios-realtime-audio-buffer
//
//  Created by Harry Lundstrom on 18/01/17.
//  Copyright © 2017 Harry Lundström. All rights reserved.
//

/*
 todo:
    - remove unused code
    - encapsulate better
    - clean up resources
    - error checking
    - correct behavious with the rest of the iOS audio eco-system,
        determine what needs to be done when suspending/resuming app
 
 */

#import "RTAudioBuffer.h"
#import <AudioUnit/AudioUnit.h>
#import <AudioToolbox/AudioSession.h>
#import <AVFoundation/AVFoundation.h>

@implementation RTAudioBuffer

AudioUnit *audioUnit = NULL;
float *convertedSampleBuffer = NULL;

void runAudio(void) {
    initAudioSession();
    initAudioStreams();
    int res = startAudioUnit();
    if(res != 1) {
        NSLog(@"startAudioUnit error");
    }
}

int initAudioSession(void) {
  
    audioUnit = (AudioUnit*)malloc(sizeof(AudioUnit));
    
    /*
    if(AudioSessionInitialize(NULL, NULL, NULL, NULL) != noErr) {
        return 1;
    }*/
    [[AVAudioSession sharedInstance] setActive:YES error:nil];
    
    /*
    if(AudioSessionSetActive(true) != noErr) {
        return 1;
    }*/
    
    /*
    UInt32 sessionCategory = kAudioSessionCategory_PlayAndRecord;
    if(AudioSessionSetProperty(kAudioSessionProperty_AudioCategory,
                               sizeof(UInt32), &sessionCategory) != noErr) {
        return 1;
    }
     */
  /*  [[AVAudioSession sharedInstance] setCategory:AVAudioSessionCategoryPlayAndRecord
                                     withOptions:AVAudioSessionCategoryOptionMixWithOthers
                                           error:nil];
   */
    
    [[AVAudioSession sharedInstance]
     setCategory:AVAudioSessionCategoryPlayback error:nil];
    
    
    /*
    Float32 bufferSizeInSec = 0.02f;
    if(AudioSessionSetProperty(kAudioSessionProperty_PreferredHardwareIOBufferDuration,
                               sizeof(Float32), &bufferSizeInSec) != noErr) {
        return 1;
    }*/
    
   /* UInt32 overrideCategory = 1;
    if(AudioSessionSetProperty(kAudioSessionProperty_OverrideCategoryDefaultToSpeaker,
                               sizeof(UInt32), &overrideCategory) != noErr) {
        return 1;
    }*/
    
    // There are many properties you might want to provide callback functions for:
    // kAudioSessionProperty_AudioRouteChange
    // kAudioSessionProperty_OverrideCategoryEnableBluetoothInput
    // etc.
    
    return 0;
}

int initAudioStreams(void) {
   /* UInt32 audioCategory = kAudioSessionCategory_PlayAndRecord;
    if(AudioSessionSetProperty(kAudioSessionProperty_AudioCategory,
                               sizeof(UInt32), &audioCategory) != noErr) {
        return 1;
    }*/
    
    /*
    UInt32 overrideCategory = 1;
    if(AudioSessionSetProperty(kAudioSessionProperty_OverrideCategoryDefaultToSpeaker,
                               sizeof(UInt32), &overrideCategory) != noErr) {
        // Less serious error, but you may want to handle it and bail here
    }*/
    
    AudioComponentDescription componentDescription;
    componentDescription.componentType = kAudioUnitType_Output;
    componentDescription.componentSubType = kAudioUnitSubType_RemoteIO;
    componentDescription.componentManufacturer = kAudioUnitManufacturer_Apple;
    componentDescription.componentFlags = 0;
    componentDescription.componentFlagsMask = 0;
    AudioComponent component = AudioComponentFindNext(NULL, &componentDescription);
    if(AudioComponentInstanceNew(component, audioUnit) != noErr) {
        return 1;
    }
   
    /*
    UInt32 enable = 1;
    if(AudioUnitSetProperty(*audioUnit, kAudioOutputUnitProperty_EnableIO,
                            kAudioUnitScope_Input, 1, &enable, sizeof(UInt32)) != noErr) {
        return 1;
    }*/
    
    AURenderCallbackStruct callbackStruct;
    callbackStruct.inputProc = renderCallback; // Render function
    callbackStruct.inputProcRefCon = NULL;
    if(AudioUnitSetProperty(*audioUnit, kAudioUnitProperty_SetRenderCallback,
                            kAudioUnitScope_Input, 0, &callbackStruct,
                            sizeof(AURenderCallbackStruct)) != noErr) {
        return 1;
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
    if(AudioUnitSetProperty(*audioUnit, kAudioUnitProperty_StreamFormat,
                            kAudioUnitScope_Input, 0, &streamDescription, sizeof(streamDescription)) != noErr) {
        return 1;
    }
    
    // Ditto for the output stream, which we will be sending the processed audio to
    if(AudioUnitSetProperty(*audioUnit, kAudioUnitProperty_StreamFormat,
                            kAudioUnitScope_Output, 1, &streamDescription, sizeof(streamDescription)) != noErr) {
        return 1;
    }
    
    return 0;
}

int startAudioUnit(void) {
    if(AudioUnitInitialize(*audioUnit) != noErr) {
        return 1;
    }
    if(AudioOutputUnitStart(*audioUnit) != noErr) {
        return 1;
    }
    return 0;
}

int stopProcessingAudio(void) {
    if(AudioOutputUnitStop(*audioUnit) != noErr) {
        return 1;
    }
    if(AudioUnitUninitialize(*audioUnit) != noErr) {
        return 1;
    }
    *audioUnit = NULL;
    return 0;
}

OSStatus renderCallback(void *userData,
                        AudioUnitRenderActionFlags *actionFlags,
                        const AudioTimeStamp *audioTimeStamp,
                        UInt32 busNumber,
                        UInt32 numFrames,
                        AudioBufferList *buffers) {
    
    
   /*
    OSStatus status = AudioUnitRender(*audioUnit, actionFlags, audioTimeStamp,
                                      1, numFrames, buffers);
    if(status != noErr) {
        NSError *error = [NSError errorWithDomain:NSOSStatusErrorDomain code:status userInfo:nil];
        NSLog(@"renderCallback:%@", error);
        return status;
    }
    */
    
  //  if(convertedSampleBuffer == NULL) {
        // Lazy initialization of this buffer is necessary because we don't
        // know the frame count until the first callback
   //     convertedSampleBuffer = (float*)malloc(sizeof(float) * numFrames);
   // }
    
    SInt16 *inputFrames = (SInt16*)(buffers->mBuffers->mData);
    
    // If your DSP code can use integers, then don't bother converting to
    // floats here, as it just wastes CPU. However, most DSP algorithms rely
    // on floating point, and this is especially true if you are porting a
    // VST/AU to iOS.
   // for(int i = 0; i < numFrames; i++) {
   //     convertedSampleBuffer[i] = (float)inputFrames[i] / 32768.0;
   // }
    
    // Now we have floating point sample data from the render callback! We
    // can send it along for further processing, for example:
    // plugin->processReplacing(convertedSampleBuffer, NULL, sampleFrames);
    
    // Assuming that you have processed in place, we can now write the
    // floating point data back to the input buffer.
    for(int i = 0; i < numFrames; i++) {
        // Note that we multiply by 32767 here, NOT 32768. This is to avoid
        // overflow errors (and thus clipping).
        printf("frames\n");
        
        inputFrames[i] = (rand() % 32767) -16000;
    }
    
    return noErr;
}
@end
