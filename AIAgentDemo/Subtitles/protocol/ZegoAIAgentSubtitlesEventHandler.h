//
//  ZegoAIAgentSubtitlesEventHandler.h
//  ai_agent_uikit
//
//  Created on 2024/7/15.
//  Copyright © 2024 Zego. All rights reserved.
//

#import <Foundation/Foundation.h>

#import "../core/ZegoAIAgentSubtitlesDefines.h"

NS_ASSUME_NONNULL_BEGIN

/**
 * @protocol ZegoAIAgentSubtitlesEventHandler
 * @brief 字幕事件处理协议
 */
@protocol ZegoAIAgentSubtitlesEventHandler <NSObject>

/**
 * 接收到聊天状态变更
 * @param state 聊天状态
 */
- (void)onRecvChatStateChange:(ZegoAIAgentSessionState)state;

/**
 * 接收到ASR聊天消息
 * @param message 聊天消息
 */
- (void)onRecvAsrChatMsg:(ZegoAIAgentAudioSubtitlesMessage*)message;

/**
 * 接收到LLM聊天消息
 * @param message 聊天消息
 */
- (void)onRecvLLMChatMsg:(ZegoAIAgentAudioSubtitlesMessage*)message;

/**
 * 接收到Express实验性API内容
 * @param content API内容
 */
- (void)onExpressExperimentalAPIContent:(NSString *)content;

@end

NS_ASSUME_NONNULL_END

