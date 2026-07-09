//
//  DYYYFLEXArgumentInputTextView.h
//  FLEXInjected
//
//  Created by Ryan Olson on 6/15/14.
//
//

#import "DYYYFLEXArgumentInputView.h"

@interface DYYYFLEXArgumentInputTextView : DYYYFLEXArgumentInputView <UITextViewDelegate>

// For subclass eyes only

@property (nonatomic, readonly) UITextView *inputTextView;
@property (nonatomic) NSString *inputPlaceholderText;

@end
