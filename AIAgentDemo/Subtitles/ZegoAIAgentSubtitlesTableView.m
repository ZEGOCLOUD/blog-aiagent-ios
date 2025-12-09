//
//  ZegoAudioChatTableView.m
//
//  Created by zego on 2024/5/13.
//  Copyright © 2024 Zego. All rights reserved.
//

#import "ZegoAIAgentSubtitlesTableView.h"
#import "views/ZegoAIAgentSubtitlesTableViewCell.h"
#import "views/ZegoAIAgentSubtitlesMessageModel.h"

@interface ZegoAIAgentSubtitlesTableView ()<UITableViewDataSource, UITableViewDelegate>
@property (nonatomic, strong) NSMutableArray<ZegoAIAgentSubtitlesMessageModel*>* chatMsgList;
@property (nonatomic, strong) NSMutableDictionary<NSString*,ZegoAIAgentSubtitlesMessageModel*>* tempAsrMsgList;
@property (nonatomic, strong) NSMutableDictionary<NSNumber*,NSMutableDictionary<NSNumber*, ZegoAIAgentSubtitlesMessageModel*>*>* tempLLMMsgList;
@property (nonatomic, strong) NSMutableOrderedSet<NSNumber*>* roundEndFlag;
@end

@implementation ZegoAIAgentSubtitlesTableView

-(instancetype)initWithFrame:(CGRect)frame style:(UITableViewStyle)style{
    if (self = [super initWithFrame:frame style:style]) {
        self.colors = [[ZegoAIAgentSubtitlesColors alloc]
                       initWithMyBackgroundColor:[UIColor colorWithRed:52/255.0 green:120/255.0 blue:252/255.0 alpha:1.0]
                                     myTextColor:[UIColor whiteColor]
                            otherBackgroundColor:[UIColor whiteColor]
                                  otherTextColor:[UIColor blackColor]];

        self.chatMsgList = [[NSMutableArray alloc] initWithCapacity:100];
        self.tempAsrMsgList = [[NSMutableDictionary alloc] initWithCapacity:5];
        self.tempLLMMsgList = [[NSMutableDictionary alloc] initWithCapacity:5];
        self.roundEndFlag = [[NSMutableOrderedSet alloc] initWithCapacity:5];

        self.separatorStyle = UITableViewCellSeparatorStyleNone;
        self.tableFooterView = [[UIView alloc] init];
        self.estimatedRowHeight = 0.0;
        self.estimatedSectionFooterHeight = 0.0;
        self.estimatedSectionHeaderHeight = 0.0;
        self.contentInset = UIEdgeInsetsMake(0, 0, 10, 0);
        self.backgroundColor = [UIColor clearColor];
        self.dataSource = self;
        self.delegate = self;

        [self registerClass:[ZegoAIAgentSubtitlesTableViewCell class] forCellReuseIdentifier:@"ZegoAudioChatTableViewCell"];
        UITapGestureRecognizer *tap = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(tap:)];
        [self addGestureRecognizer:tap];
    }
    return self;
}

- (void)tap:(UIGestureRecognizer *) recognizer {}

-(void)handleRecvAsrMessage:(ZegoAIAgentAudioSubtitlesMessage*)message{
    long long messageSeqId = message.seq_id;
    long long messageRound = message.round;
    long messageTimeStamp = message.timestamp;
    NSString* messageContent = message.data.text;
    NSString* messageId = message.data.message_id;
    BOOL messageEndFlag = message.data.end_flag;

    if (messageContent && messageContent.length > 0) {
        ZegoAIAgentSubtitlesMessageModel* existAsrMsgModel = [self.tempAsrMsgList objectForKey:messageId];
        if (existAsrMsgModel == nil) {
            existAsrMsgModel = [[ZegoAIAgentSubtitlesMessageModel alloc] init];
            existAsrMsgModel.seqId = messageSeqId;
            existAsrMsgModel.isMine = YES;
            existAsrMsgModel.content = messageContent;
            existAsrMsgModel.round = messageRound;
            existAsrMsgModel.end_flag = messageEndFlag;
            existAsrMsgModel.message_id = messageId;
            existAsrMsgModel.messageTimeStamp = messageTimeStamp;
            [self.tempAsrMsgList setObject:existAsrMsgModel forKey:messageId];
            [self insertCurMsgModel:existAsrMsgModel];
        } else if(existAsrMsgModel.message_id && [existAsrMsgModel.message_id isEqualToString:messageId]){
            if (messageSeqId >= existAsrMsgModel.seqId) {
                existAsrMsgModel.content = messageContent;
                existAsrMsgModel.seqId = messageSeqId;
                [self reloadMessages];
            }
        }
    }
}

-(void)handleRecvLLMMessage:(ZegoAIAgentAudioSubtitlesMessage*)message{
    long long messageSeqId = message.seq_id;
    long long messageRound = message.round;
    long messageTimeStamp = message.timestamp;
    NSString* messageContent = message.data.text;
    NSString* messageId = message.data.message_id;
    BOOL messageEndFlag = message.data.end_flag;

    if (messageContent && messageContent.length > 0) {
        NSNumber* objSeqId = [NSNumber numberWithLongLong:messageSeqId];
        ZegoAIAgentSubtitlesMessageModel* newMsgModel = [[ZegoAIAgentSubtitlesMessageModel alloc] init];
        newMsgModel.seqId = messageSeqId;
        newMsgModel.isMine = NO;
        newMsgModel.content = messageContent;
        newMsgModel.round = messageRound;
        newMsgModel.message_id = messageId;
        newMsgModel.end_flag = messageEndFlag;
        newMsgModel.messageTimeStamp = messageTimeStamp;

        NSMutableDictionary<NSNumber*,ZegoAIAgentSubtitlesMessageModel*>* existMsgList = [self.tempLLMMsgList objectForKey:@(messageRound)];
        if (existMsgList == nil) {
            existMsgList = [[NSMutableDictionary alloc] initWithCapacity:5];
            [existMsgList setObject:newMsgModel forKey:objSeqId];
            [self.tempLLMMsgList setObject:existMsgList forKey:@(messageRound)];

            ZegoAIAgentSubtitlesMessageModel* chatCellModel = [[ZegoAIAgentSubtitlesMessageModel alloc] init];
            chatCellModel.seqId = messageSeqId;
            chatCellModel.isMine = NO;
            chatCellModel.content = messageContent;
            chatCellModel.round = messageRound;
            chatCellModel.message_id = messageId;
            chatCellModel.end_flag = messageEndFlag;
            chatCellModel.messageTimeStamp = messageTimeStamp;
            [self insertCurMsgModel:chatCellModel];
        } else {
            id firstSeqIdKey = [existMsgList allKeys].firstObject;
            ZegoAIAgentSubtitlesMessageModel* firstValue = [existMsgList objectForKey:firstSeqIdKey];
            if (![messageId isEqualToString:firstValue.message_id]) {
                NSArray *seqIDKeys = [existMsgList allKeys];
                NSNumber *maxSeqIdKey = [seqIDKeys firstObject];
                for (NSNumber *seqIdKey in seqIDKeys) {
                    if ([seqIdKey compare:maxSeqIdKey] == NSOrderedDescending) { maxSeqIdKey = seqIdKey; }
                }
                if (messageSeqId > [maxSeqIdKey longLongValue]) {
                    [existMsgList removeAllObjects];
                    [self handleMessageIdChange:firstValue.message_id newModel:newMsgModel];
                }
            }
            [existMsgList setObject:newMsgModel forKey:objSeqId];
            [self updateLLMContent:existMsgList messageId:messageId endFlag:messageEndFlag timeStamp:messageTimeStamp seqId:messageSeqId];
        }
    }

    if (self.roundEndFlag.count < 3) {
        [self.roundEndFlag addObject:@(messageRound)];
    } else {
        NSNumber* key = self.roundEndFlag.firstObject;
        [self.tempLLMMsgList removeObjectForKey:key];
        [self.roundEndFlag removeObject:key];
    }
}

-(void)handleMessageIdChange:(NSString*)oldMessageId newModel:(ZegoAIAgentSubtitlesMessageModel*)newModel {
    NSInteger oldIndex = -1;
    for (NSInteger i = 0; i < self.chatMsgList.count; i++) {
        ZegoAIAgentSubtitlesMessageModel* msgModel = self.chatMsgList[i];
        if ([msgModel.message_id isEqualToString:oldMessageId]) {
            oldIndex = i;
            [self.chatMsgList removeObjectAtIndex:i];
            break;
        }
    }
    if (oldIndex >= 0) {
        [self.chatMsgList insertObject:newModel atIndex:oldIndex];
        [self reloadMessages];
    } else {
        [self insertCurMsgModel:newModel];
    }
}

-(void)updateLLMContent:(NSMutableDictionary*)existMsgList messageId:(NSString*)messageId endFlag:(BOOL)endFlag timeStamp:(long)timeStamp seqId:(long long)seqId {
    NSArray *seqIdKeysArray = [existMsgList allKeys];
    NSArray *sortedSeqIdsArray = [seqIdKeysArray sortedArrayUsingComparator:^NSComparisonResult(id obj1, id obj2) {
        return [(NSNumber*)obj1 longLongValue] > [(NSNumber*)obj2 longLongValue];
    }];

    NSString* totalContent = @"";
    for (NSNumber* seqIdKey in sortedSeqIdsArray) {
        ZegoAIAgentSubtitlesMessageModel* temp = [existMsgList objectForKey:seqIdKey];
        totalContent = [totalContent stringByAppendingString:temp.content];
    }

    ZegoAIAgentSubtitlesMessageModel* curMsgModel = [self queryMsgModelWithMessageId:messageId];
    if (curMsgModel) {
        curMsgModel.seqId = seqId;
        curMsgModel.isMine = NO;
        curMsgModel.end_flag = endFlag;
        curMsgModel.messageTimeStamp = timeStamp;
        curMsgModel.content = totalContent;
        [self reloadMessages];
    }
}

-(void)insertCurMsgModel:(ZegoAIAgentSubtitlesMessageModel*)curMsgModel {
    if (curMsgModel == nil) { return; }
    [self.chatMsgList addObject:curMsgModel];
    [self reloadMessages];
}

-(void)reloadMessages {
    [self reloadData];
    if (self.chatMsgList.count > 0) {
        NSIndexPath* indexPath = [NSIndexPath indexPathForItem:self.chatMsgList.count-1 inSection:0];
        [self scrollToRowAtIndexPath:indexPath atScrollPosition:UITableViewScrollPositionBottom animated:NO];
    }
}

-(ZegoAIAgentSubtitlesMessageModel*)queryMsgModelWithMessageId:(NSString*)msgId {
    for (ZegoAIAgentSubtitlesMessageModel* msgModel in self.chatMsgList) {
        if ([msgModel.message_id isEqualToString:msgId]) { return msgModel; }
    }
    return nil;
}

#pragma mark - UITableViewDataSource

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView { return 1; }

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    return self.chatMsgList.count;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    static NSString *cellIdentifier = @"ZegoAudioChatTableViewCell";
    ZegoAIAgentSubtitlesTableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:cellIdentifier];
    if (cell == nil) {
        cell = [[ZegoAIAgentSubtitlesTableViewCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:cellIdentifier];
    }
    cell.colors = self.colors;
    cell.selectionStyle = UITableViewCellSelectionStyleNone;
    ZegoAIAgentSubtitlesMessageModel* msgModel = self.chatMsgList[indexPath.row];
    cell.msgModel = msgModel;
    return cell;
}

- (CGFloat)tableView:(UITableView *)tableView heightForRowAtIndexPath:(NSIndexPath *)indexPath {
    ZegoAIAgentSubtitlesMessageModel* msgModel = self.chatMsgList[indexPath.row];
    CGRect rect = msgModel.boundingBox;
    return rect.size.height + CELL_TOP_MARGIN;
}

- (CGFloat)tableView:(UITableView *)tableView estimatedHeightForRowAtIndexPath:(NSIndexPath *)indexPath {
    return 44;
}

@end

