//
//  ZegoAgentMessageContent.h
//  ai_agent_uikit
//
//  Created by Zego 2024/4/11.
//  Copyright © 2024 ZEGO. All rights reserved.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

typedef NS_ENUM(NSInteger, ZegoAIAgentSubtitlesMessageCommand) {
    ZegoAgentMessageCmdUserSpeakStatus = 1,
    ZegoAgentMessageCmdAgentSpeakStatus = 2,
    ZegoAgentMessageCmdASRText = 3,
    ZegoAgentMessageCmdLLMText = 4
};

typedef NS_ENUM(NSInteger, ZegoAIAgentSubtitlesSpeakStatus) {
    ZegoAgentSpeakStatusStart = 1,
    ZegoAgentSpeakStatusEnd = 2
};

@interface ZegoAIAgentSubtitlesSpeakStatusData : NSObject
@property (nonatomic, assign) ZegoAIAgentSubtitlesSpeakStatus speakStatus;
- (instancetype)initWithDictionary:(NSDictionary *)dict;
- (NSDictionary *)toDictionary;
@end

@interface ZegoAIAgentSubtitlesASRTextData : NSObject
@property (nonatomic, copy) NSString *text;
@property (nonatomic, copy) NSString *messageId;
@property (nonatomic, assign) BOOL endFlag;
- (instancetype)initWithDictionary:(NSDictionary *)dict;
- (NSDictionary *)toDictionary;
@end

@interface ZegoAIAgentSubtitlesLLMTextData : NSObject
@property (nonatomic, copy) NSString *text;
@property (nonatomic, copy) NSString *messageId;
@property (nonatomic, assign) BOOL endFlag;
- (instancetype)initWithDictionary:(NSDictionary *)dict;
- (NSDictionary *)toDictionary;
@end

@interface ZegoAIAgentSubtitlesMessageProtocol : NSObject
@property (nonatomic, assign) int64_t timestamp;
@property (nonatomic, assign) int64_t seqId;
@property (nonatomic, assign) int64_t round;
@property (nonatomic, assign) ZegoAIAgentSubtitlesMessageCommand cmdType;
@property (nonatomic, strong) NSDictionary *data;
@property (nonatomic, strong, readonly, nullable) ZegoAIAgentSubtitlesSpeakStatusData *userSpeakData;
@property (nonatomic, strong, readonly, nullable) ZegoAIAgentSubtitlesSpeakStatusData *agentSpeakData;
@property (nonatomic, strong, readonly, nullable) ZegoAIAgentSubtitlesASRTextData *asrTextData;
@property (nonatomic, strong, readonly, nullable) ZegoAIAgentSubtitlesLLMTextData *llmTextData;
- (instancetype)initWithDictionary:(NSDictionary *)jsonDict;
- (NSDictionary *)toDictionary;
@end

NS_ASSUME_NONNULL_END

