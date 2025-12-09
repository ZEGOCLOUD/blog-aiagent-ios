//
//  ZegoAIAgentSubtitlesTableView.h
//
//  Created by Zego 2024/4/11.
//  Copyright © 2024 Zego. All rights reserved.
//

#import <UIKit/UIKit.h>

#import "views/ZegoAIAgentSubtitlesMessageModel.h"
#import "core/ZegoAIAgentSubtitlesColors.h"
#import "core/ZegoAIAgentSubtitlesDefines.h"

@protocol ZegoAIAgentSubtitlesEventHandler;

NS_ASSUME_NONNULL_BEGIN

/**
 * @class ZegoAIAgentSubtitlesTableView
 * @brief 智能体对话字幕表格视图
 */
@interface ZegoAIAgentSubtitlesTableView : UITableView

@property (nonatomic, strong) ZegoAIAgentSubtitlesColors *colors;

-(void)handleRecvAsrMessage:(ZegoAIAgentAudioSubtitlesMessage*)message;
-(void)handleRecvLLMMessage:(ZegoAIAgentAudioSubtitlesMessage*)message;
@end

NS_ASSUME_NONNULL_END

