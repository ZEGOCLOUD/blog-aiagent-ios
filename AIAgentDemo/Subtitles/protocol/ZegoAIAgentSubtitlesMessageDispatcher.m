//
//  ZegoAIAgentChatMessageDispatcher.m
//  ai_agent_uikit
//
//  Created on 2024/7/15.
//  Copyright © 2024 Zego. All rights reserved.
//

#import "ZegoAIAgentSubtitlesMessageDispatcher.h"
#import "ZegoAIAgentSubtitlesMessageProtocol.h"

@interface ZegoAIAgentSubtitlesMessageDispatcher ()
@property (nonatomic, strong) NSHashTable<id<ZegoAIAgentSubtitlesEventHandler>> *eventHandlers;
@property (nonatomic, assign) int64_t lastCMD1Seq;
@property (nonatomic, assign) ZegoAIAgentSessionState chatSessionState;
@end

@implementation ZegoAIAgentSubtitlesMessageDispatcher

#pragma mark - Singleton

+ (instancetype)sharedInstance {
    static ZegoAIAgentSubtitlesMessageDispatcher *instance = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        instance = [[self alloc] init];
    });
    return instance;
}

- (instancetype)init {
    if (self = [super init]) {
        self.eventHandlers = [NSHashTable weakObjectsHashTable];
        self.lastCMD1Seq = 0;
        self.chatSessionState = SubtitlesSessionState_UNINIT;
    }
    return self;
}

#pragma mark - Public Methods

- (void)registerEventHandler:(id<ZegoAIAgentSubtitlesEventHandler>)handler {
    if (handler) {
        @synchronized (self.eventHandlers) {
            [self.eventHandlers addObject:handler];
        }
    }
}

- (void)unregisterEventHandler:(id<ZegoAIAgentSubtitlesEventHandler>)handler {
    if (handler) {
        @synchronized (self.eventHandlers) {
            [self.eventHandlers removeObject:handler];
        }
    }
}

- (void)handleExpressExperimentalAPIContent:(NSString *)content {
    if (content == nil) { return; }

    @synchronized (self.eventHandlers) {
        for (id<ZegoAIAgentSubtitlesEventHandler> handler in self.eventHandlers) {
            if ([handler respondsToSelector:@selector(onExpressExperimentalAPIContent:)]) {
                [handler onExpressExperimentalAPIContent:content];
            }
        }
    }

    NSDictionary* contentDict = [self dictFromJson:content];
    if (!contentDict) { return; }

    NSString *method = contentDict[@"method"];
    if (![method isEqualToString:@"liveroom.room.on_recive_room_channel_message"]) { return; }

    NSDictionary *params = contentDict[@"params"];
    if (!params) { return; }

    NSString *msgContent = params[@"msg_content"];
    NSString *sendIdName = params[@"send_idname"];
    NSString *sendNickname = params[@"send_nickname"];

    if (!msgContent || !sendIdName) { return; }

    [self handleMessageContent:msgContent userID:sendIdName userName:sendNickname ?: @""];
}

- (void)handleMessageContent:(NSString *)command userID:(NSString *)userID userName:(NSString *)userName {
    if (command == nil) { return; }

    NSDictionary* msgDict = [self dictFromJson:command];
    ZegoAIAgentSubtitlesMessageProtocol *messageProtocol = [[ZegoAIAgentSubtitlesMessageProtocol alloc] initWithDictionary:msgDict];

    ZegoAIAgentSubtitlesMessageCommand cmd = messageProtocol.cmdType;
    int64_t seqId = messageProtocol.seqId;
    int64_t round = messageProtocol.round;
    int64_t timeStamp = messageProtocol.timestamp;

    ZegoAIAgentAudioSubtitlesMessage* cmdMsg = [[ZegoAIAgentAudioSubtitlesMessage alloc] init];
    cmdMsg.cmd = (int)cmd;
    cmdMsg.seq_id = seqId;
    cmdMsg.round = round;
    cmdMsg.timestamp = timeStamp;

    if(cmd == ZegoAgentMessageCmdASRText){
        if(messageProtocol.asrTextData) {
            cmdMsg.data = [[ZegoAIAgentSubtitlesCommand alloc] init];
            cmdMsg.data.text = messageProtocol.asrTextData.text;
            cmdMsg.data.message_id = messageProtocol.asrTextData.messageId;
            cmdMsg.data.end_flag = messageProtocol.asrTextData.endFlag;
            [self dispatchAsrChatMsg:cmdMsg];
        }
    } else if(cmd == ZegoAgentMessageCmdLLMText){
        if(messageProtocol.llmTextData) {
            cmdMsg.data = [[ZegoAIAgentSubtitlesCommand alloc] init];
            cmdMsg.data.text = messageProtocol.llmTextData.text;
            cmdMsg.data.message_id = messageProtocol.llmTextData.messageId;
            cmdMsg.data.end_flag = messageProtocol.llmTextData.endFlag;
            [self dispatchLLMChatMsg:cmdMsg];
        }
    } else if(cmd == ZegoAgentMessageCmdUserSpeakStatus){
        if(messageProtocol.userSpeakData) {
            int speakStatus = (int)messageProtocol.userSpeakData.speakStatus;
            if (seqId < self.lastCMD1Seq) { return; }
            if(speakStatus == ZegoAgentSpeakStatusStart){
                self.chatSessionState = SubtitlesSessionState_AI_LISTEN;
                [self dispatchChatStateChange:SubtitlesSessionState_AI_LISTEN];
            } else if(speakStatus == ZegoAgentSpeakStatusEnd){
                self.chatSessionState = SubtitlesSessionState_AI_THINKING;
                [self dispatchChatStateChange:SubtitlesSessionState_AI_THINKING];
            }
            self.lastCMD1Seq = seqId;
        }
    } else if(cmd == ZegoAgentMessageCmdAgentSpeakStatus){
        if(messageProtocol.agentSpeakData) {
            int speakStatus = (int)messageProtocol.agentSpeakData.speakStatus;
            if(speakStatus == ZegoAgentSpeakStatusStart){
                self.chatSessionState = SubtitlesSessionState_AI_SPEAKING;
                [self dispatchChatStateChange:SubtitlesSessionState_AI_SPEAKING];
            } else if(speakStatus == ZegoAgentSpeakStatusEnd){
                self.chatSessionState = SubtitlesSessionState_AI_LISTEN;
                [self dispatchChatStateChange:SubtitlesSessionState_AI_LISTEN];
            }
        }
    }
}

- (NSDictionary *)dictFromJson:(NSString *)jsonString {
    if (jsonString == nil) { return nil; }
    NSError *error;
    NSData *jsonData = [jsonString dataUsingEncoding:NSUTF8StringEncoding];
    if (!jsonData) { return nil; }
    NSDictionary *dic = [NSJSONSerialization JSONObjectWithData:jsonData options:NSJSONReadingMutableContainers error:&error];
    if(error) { return nil; }
    return dic;
}

#pragma mark - Private Methods

- (void)dispatchChatStateChange:(ZegoAIAgentSessionState)state {
    @synchronized (self.eventHandlers) {
        for (id<ZegoAIAgentSubtitlesEventHandler> handler in self.eventHandlers) {
            if ([handler respondsToSelector:@selector(onRecvChatStateChange:)]) {
                [handler onRecvChatStateChange:state];
            }
        }
    }
}

- (void)dispatchAsrChatMsg:(ZegoAIAgentAudioSubtitlesMessage*)message {
    @synchronized (self.eventHandlers) {
        for (id<ZegoAIAgentSubtitlesEventHandler> handler in self.eventHandlers) {
            if ([handler respondsToSelector:@selector(onRecvAsrChatMsg:)]) {
                [handler onRecvAsrChatMsg:message];
            }
        }
    }
}

- (void)dispatchLLMChatMsg:(ZegoAIAgentAudioSubtitlesMessage*)message {
    @synchronized (self.eventHandlers) {
        for (id<ZegoAIAgentSubtitlesEventHandler> handler in self.eventHandlers) {
            if ([handler respondsToSelector:@selector(onRecvLLMChatMsg:)]) {
                [handler onRecvLLMChatMsg:message];
            }
        }
    }
}

@end

