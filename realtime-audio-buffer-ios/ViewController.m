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
 
 */

#import "ViewController.h"
#import <AVFoundation/AVFoundation.h>
#import "RTAudioBuffer.h"
#import <pthread.h>

@interface ViewController ()
@end

@implementation ViewController

pthread_mutex_t mutex = PTHREAD_MUTEX_INITIALIZER;
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
    // When generating samples from a data structure such as a synthesizer that is controlled from
    // another thread, use a mutex to prevent the two threads from manupulating the data at the same time.
    // The code that manipulates the structure in the UI thread needs to be enclosed with the same mutex.
    // Try to keep the work inside the locks to a minimum to prevent stalling.
    pthread_mutex_lock(&mutex);
    // write samples
    for(int i = 0; i < totalFrames; i+=2) {
        inputFrames[i] = 0; // write silence to the left channel
        inputFrames[i+1] = (rand() % INT16_MAX) -INT16_MAX/2; // write noise to the right channel
    }
    pthread_mutex_unlock(&mutex);
    return noErr;
}

- (void)viewDidLoad {
    [super viewDidLoad];
    [self addObservers];
    [self initAudio];
}

- (void)initAudio {
    // set the renderCallback and a preferred bufferduration (latency) of 0.02 seconds
    rtAudioInitWithCallback(renderCallback, 0.02);
}

- (void)handleApplicationWillTerminate:(NSNotification*)notification {
    NSLog(@"handleApplicationWillTerminate: %@", notification);
    [self removeObservers];
    rtAudioStopAudioUnit();
}

- (void)handleAudioSessionRouteChanged:(NSNotification*)notification {
    NSLog(@"handleAudioSessionRouteChanged: %@", notification);
}

- (void)handleAudioSessionInterruption:(NSNotification*)notification {
    NSLog(@"handleAudioSessionInterruption: %@", notification);
    NSNumber *interruptionType = [[notification userInfo] objectForKey:AVAudioSessionInterruptionTypeKey];
    NSNumber *interruptionOption = [[notification userInfo] objectForKey:AVAudioSessionInterruptionOptionKey];
    switch (interruptionType.unsignedIntegerValue) {
        case AVAudioSessionInterruptionTypeBegan:{
            NSLog(@"AVAudioSessionInterruptionTypeBegan");
        } break;
        case AVAudioSessionInterruptionTypeEnded: {
            NSLog(@"AVAudioSessionInterruptionTypeEnded");
            if (interruptionOption.unsignedIntegerValue == AVAudioSessionInterruptionOptionShouldResume) {
                NSLog(@"AVAudioSessionInterruptionOptionShouldResume");
                // resume audio by reconfiguring, perhaps it could be done without reconfiguring everything from ground up.
                [self initAudio];
            }
        } break;
        default:
            break;
    }
}

- (void)handleMediaServicesReset {
    NSLog(@"handleMediaServicesReset");
    /* - No userInfo dictionary for this notification
       - Audio streaming objects are invalidated (zombies)
       - Handle this notification by fully reconfiguring audio */
    [self initAudio];
}

- (void)addObservers {
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(handleApplicationWillTerminate:)
                                                 name:UIApplicationWillTerminateNotification
                                               object:nil];
    
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(handleAudioSessionRouteChanged:)
                                                 name:AVAudioSessionRouteChangeNotification
                                               object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(handleAudioSessionInterruption:)
                                                 name:AVAudioSessionInterruptionNotification
                                               object:[AVAudioSession sharedInstance]];
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(handleMediaServicesReset)
                                                 name:AVAudioSessionMediaServicesWereResetNotification
                                               object:[AVAudioSession sharedInstance]];
}

- (void)removeObservers {
    [[NSNotificationCenter defaultCenter] removeObserver:self name:UIApplicationWillTerminateNotification object:nil];
    [[NSNotificationCenter defaultCenter] removeObserver:self name:AVAudioSessionRouteChangeNotification object:nil];
    [[NSNotificationCenter defaultCenter] removeObserver:self name:AVAudioSessionInterruptionNotification object:[AVAudioSession sharedInstance]];
    [[NSNotificationCenter defaultCenter] removeObserver:self name:AVAudioSessionMediaServicesWereResetNotification object:[AVAudioSession sharedInstance]];
}

@end
