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

#import "ViewController.h"
#import <AVFoundation/AVFoundation.h>
#import "RTAudioBuffer.h"

@interface ViewController ()
@end
@implementation ViewController
OSStatus renderCallback(void *userData,
                        AudioUnitRenderActionFlags *actionFlags,
                        const AudioTimeStamp *audioTimeStamp,
                        UInt32 busNumber,
                        UInt32 numFrames,
                        AudioBufferList *buffers) {
    SInt16 *inputFrames = (SInt16*)(buffers->mBuffers->mData);
    int totalFrames = numFrames*2;
    // zero the buffer
    for(int i = 0; i < totalFrames; i++) {
        inputFrames[i] = 0;
    }
    // write samples
    for(int i = 0; i < totalFrames; i+=2) {
        inputFrames[i] = 0; // write silence to the left channel
        inputFrames[i+1] = (rand() % 32767) -16000; // write noise to the right channel
    }
    return noErr;
}
- (void)viewDidLoad {
    [super viewDidLoad];
    [self addObservers];
    /* set the renderCallback and a preferred bufferduration (latency) of 0.02 seconds */
    rtAudioInitWithCallback(renderCallback, 0.02);
}
- (void)applicationWillTerminate:(NSNotification*)notification {
    NSLog(@"applicationWillTerminate: %@", notification);
    [self removeObservers];
    rtAudioStopProcessingAudio();
}
- (void)audioSessionRouteChanged:(NSNotification*)notification {
    NSLog(@"routeChanged: %@", notification);
}
- (void)addObservers {
    UIApplication *app = [UIApplication sharedApplication];
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(applicationWillTerminate:)
                                                 name:UIApplicationWillTerminateNotification
                                               object:app];
    
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(audioSessionRouteChanged:)
                                                 name:AVAudioSessionRouteChangeNotification
                                               object:nil];
}
- (void)removeObservers {
    UIApplication *app = [UIApplication sharedApplication];
    [[NSNotificationCenter defaultCenter] removeObserver:self name:UIApplicationWillTerminateNotification object:app];
    [[NSNotificationCenter defaultCenter] removeObserver:self name:AVAudioSessionRouteChangeNotification object:nil];
}
- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
}
@end
