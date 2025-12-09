//
//  ZegoAudioChatTableViewCell.m
//
//  Created by zego on 2024/5/13.
//  Copyright © 2024 Zego. All rights reserved.
//

#import "ZegoAIAgentSubtitlesTableViewCell.h"
#import "ZegoAIAgentSubtitlesMessageModel.h"
#import "ZegoAIAgentSubtitlesCellLabelView.h"

@interface ZegoAIAgentSubtitlesTableViewCell ()
@property (nonatomic, strong, readwrite) ZegoAIAgentSubtitlesCellLabelView *text;
@end

@implementation ZegoAIAgentSubtitlesTableViewCell

- (instancetype)initWithFrame:(CGRect)frame {
    self = [super initWithFrame:frame];
    if (self) {
    }
    
    return self;
}

-(void)layoutSubviews{
    [super layoutSubviews];
    self.backgroundColor = [UIColor clearColor];
}

-(void)setMsgModel:(ZegoAIAgentSubtitlesMessageModel*)msgModel{
    for (UIView *subview in self.subviews) {
        [subview removeFromSuperview];
    }
    self.text = [[ZegoAIAgentSubtitlesCellLabelView alloc]init];
    self.text.colors = self.colors;
    [self.text setMsgModel:msgModel];
    [self addSubview:self.text];

    CGFloat cellWidth = self.bounds.size.width;
    CGFloat labelWidth = msgModel.boundingBox.size.width;
    CGFloat labelHeight = msgModel.boundingBox.size.height;
    
    if (msgModel.isMine) {
        self.text.frame = CGRectMake(cellWidth - labelWidth - 20, CELL_TOP_MARGIN / 2, labelWidth, labelHeight);
    } else {
        self.text.frame = CGRectMake(20, CELL_TOP_MARGIN / 2, labelWidth, labelHeight);
    }
}
@end

