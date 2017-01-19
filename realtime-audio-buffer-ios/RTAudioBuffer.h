//
//  RTAudioBuffer.h
//  ios-realtime-audio-buffer
//
//  Created by Harry Lundstrom on 18/01/17.
//  Copyright © 2017 Harry Lundström. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface RTAudioBuffer : NSObject

void runAudio(void);
void startAudioUnit(void);
void stopProcessingAudio(void);

@end


