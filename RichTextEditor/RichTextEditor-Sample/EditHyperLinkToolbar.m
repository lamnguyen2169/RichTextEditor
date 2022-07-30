//
//  EditHyperLinkToolbar.m
//  RichTextEditor-Sample
//
//  Created by ChrisK on 7/5/22.
//  Copyright (c) 2022 ChrisK. All rights reserved.
//

#import "EditHyperLinkToolbar.h"

#import "NSString+Extensions.h"

@interface EditHyperLinkToolbar () <NSTextFieldDelegate>

@property (weak) IBOutlet NSView *containerView;
@property (weak) IBOutlet NSTextField *textField;
@property (weak) IBOutlet NSButton *applyButton;

@end

@implementation EditHyperLinkToolbar

- (void)viewDidLoad {
    [super viewDidLoad];
    [self configUI];
}

- (void)viewWillAppear {
    [super viewWillAppear];
    
    if ([self.hyperlink isKindOfClass:[NSURL class]]) {
        [self.textField setStringValue:[self.hyperlink absoluteString]];
        [self reloadApplyButton];
    }
}

// MARK: -

- (void)configUI {
    [self.containerView setWantsLayer:YES];
    [[self.containerView layer] setBackgroundColor:[[NSColor whiteColor] CGColor]];
    [[self.containerView layer] setCornerRadius:8];
}

- (void)reloadApplyButton {
    NSString *urlString = [[self.textField stringValue] stringByReplacingOccurrencesOfString:@" " withString:@""];
    
    [urlString validateURL:^(bool isValid) {
        BOOL isEnabled = isValid || (urlString.length == 0);
        
        dispatch_async(dispatch_get_main_queue(), ^{
            [self.applyButton setEnabled:isEnabled];
        });
    }];
}

- (void)applyFormatLink {
    NSString *urlString = [[self.textField stringValue] stringByReplacingOccurrencesOfString:@" " withString:@""];
    NSURL *url = [NSURL URLWithString:urlString];
    
    [urlString validateURL:^(bool isValid) {
        if (isValid && (url != nil)) {
            dispatch_async(dispatch_get_main_queue(), ^{
                [self.delegate toolbarDidChangeFormatLink:url];
            });
        } else {
            [self.delegate toolbarDidChangeFormatLink:nil];
        }
    }];
}

// MARK: - Actions

- (IBAction)toggleHyperLink:(id)sender {
    [self applyFormatLink];
}

// MARK: - NSTextFieldDelegate

- (void)controlTextDidBeginEditing:(NSNotification *)obj {
}

- (void)controlTextDidEndEditing:(NSNotification *)obj {
}

- (void)controlTextDidChange:(NSNotification *)obj {
    [self reloadApplyButton];
}

- (BOOL)control:(NSControl *)control textView:(NSTextView *)textView doCommandBySelector:(SEL)commandSelector {
    if (commandSelector == @selector(insertNewline:)) {
        [self applyFormatLink];
    }
    
    return NO;
}

@end
