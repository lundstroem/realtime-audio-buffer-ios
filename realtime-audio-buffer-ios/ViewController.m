//
//  ViewController.m
//  realtime-audio-buffer-ios
//
//  Created by Harry Lundstrom on 19/01/17.
//  Copyright © 2017 Harry Lundström. All rights reserved.
//

#import "ViewController.h"
#import <AVFoundation/AVFoundation.h>
#import "RTAudioBuffer.h"

@interface ViewController ()

@end

@implementation ViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    // Do any additional setup after loading the view, typically from a nib.

    [self initNotifications];
    runAudio();
}

-(void)audio_session_route_changed:(NSNotification*)notification {
    NSLog(@"notification received: %@", notification);
}

-(void)initNotifications {
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(audio_session_route_changed:)
                                                 name:AVAudioSessionRouteChangeNotification
                                               object:nil];
}
- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}



@end
