//
//  ZegoAIAgentSubtitlesMessageModel.h
//
//  Created by Zego 2024/4/11.
//  Copyright © 2024 Zego. All rights reserved.
//

#import <Foundation/Foundation.h>
#include <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN

@interface ZegoAIAgentSubtitlesMessageModel : NSObject

@property (nonatomic, assign) int64_t seqId;
@property (nonatomic, assign) int64_t round;
@property (nonatomic, assign) BOOL isMine;
@property (nonatomic, strong) NSString *content;
@property (nonatomic, assign) int64_t messageTimeStamp;
@property (nonatomic, assign) int64_t costMs;
@property (nonatomic, assign) CGRect boundingBox;
@property (nonatomic, strong) NSString* message_id;
@property (nonatomic, assign) BOOL end_flag;

- (NSString*) description;

@end

NS_ASSUME_NONNULL_END

