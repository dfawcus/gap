/* 
   Project: Sudoku
   Controller.m

   Copyright (C) 2007-2011 The Free Software Foundation, Inc

   Author: Marko Riedel
           Riccardo Mottola

   This application is free software; you can redistribute it and/or
   modify it under the terms of the GNU General Public
   License as published by the Free Software Foundation; either
   version 3 of the License, or (at your option) any later version.
 
   This application is distributed in the hope that it will be useful,
   but WITHOUT ANY WARRANTY; without even the implied warranty of
   MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
   Library General Public License for more details.
 
   You should have received a copy of the GNU General Public
   License along with this library; if not, write to the Free
   Software Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston, MA  02110-1301, USA.
*/

#include <time.h>
time_t time(time_t *t);


#import <Foundation/Foundation.h>
#import <AppKit/AppKit.h>

#import "Controller.h"
#import "Document.h"
#import "DigitSource.h"

@implementation Controller

static NSPanel *_prog_ind_panel = nil;

#define PROG_IND_WIDTH 200
#define PROG_IND_HEIGHT 20

+ (NSPanel *)prog_ind
{
    if(_prog_ind_panel==nil)
      {
	NSRect pi_frame = NSMakeRect(0, 0, PROG_IND_WIDTH, PROG_IND_HEIGHT);
	NSProgressIndicator *_prog_ind;

        _prog_ind_panel = 
            [[NSPanel alloc]
                initWithContentRect:pi_frame
                styleMask:NSTitledWindowMask
                backing:NSBackingStoreBuffered
                defer:NO];
        [_prog_ind_panel setReleasedWhenClosed:NO];
        
	_prog_ind = [[NSProgressIndicator alloc] initWithFrame:pi_frame];
	[_prog_ind setMinValue: 0.0];
	[_prog_ind setMaxValue: 100.0];
	[_prog_ind setIndeterminate: NO];
        [_prog_ind_panel setContentView:_prog_ind];

	[_prog_ind_panel setTitle:NSLocalizedString(@"Computing Sudoku", @"Title")];
    }

    [_prog_ind_panel center];
    return _prog_ind_panel;
}

#define TICK_ITER 20
#define TICK_STEP  5

typedef enum {
  STATE_FIND,
  STATE_CLUES,
  STATE_SELECT,
  STATE_DONE
} STATE;

#define MAXTRIES 25

- newPuzzle:(id)sender; // clues = [sender tag]
{
    NSApplication *app;
    NSModalSession findSession;
    NSDocumentController *dc;
    Document *doc;
    Sudoku *sdk;
    Sudoku *other;
    Sudoku *pick;
    NSPanel *pi_panel;
    NSProgressIndicator *pi;
    float percent, dir;
    STATE st;
    NSString *checkseq;
    int tries;

    app = [NSApplication sharedApplication];
    dc = [NSDocumentController sharedDocumentController];
    [dc newDocument:self];

    doc = [dc currentDocument];
    sdk = [doc sudoku];

    pi_panel = [Controller prog_ind];
    pi = [pi_panel contentView];
    
    [pi_panel makeKeyAndOrderFront:self];

    findSession = [app beginModalSessionForWindow:pi_panel];

    percent = 0;
    dir = 1;
    st = STATE_FIND;

    checkseq = nil; 
    other = [[Sudoku alloc] init];
    pick = [[Sudoku alloc] init];
    tries = 0;

    do {
	int tick;
	for(tick=0; tick<TICK_ITER; tick++)
	  {
	    [pi setDoubleValue:percent];
	    [pi display];

	    [[pi_panel contentView] setNeedsDisplay:YES];
	    [pi_panel flushWindow];

	    percent += TICK_STEP*dir;
	}
	if(percent==100.0){
	    dir = -1;
	}
	else if(percent==0.0){
	    dir = +1;
	}

	if(st==STATE_FIND){
	  if([sdk find]==YES){
	    st = STATE_CLUES;
	    [other copyStateFromSource:sdk];
	    [other setClues:[sender tag]];
	  }
	}
	else if(st==STATE_CLUES){
	  if([other selectClues]==YES){
	    [other find]; // == YES
	    st = STATE_SELECT;
	  }
	}
	else if(st==STATE_SELECT){
	  NSString *othercseq = [other checkSequence];
	  // NSLog(@"%d %@", __LINE__, checkseq);
	  // NSLog(@"%d %@", __LINE__, othercseq);
	  
	  if(checkseq==nil || 
	     [checkseq compare:othercseq]==NSOrderedDescending){
	    NSLog(@"%d tries, picked %@ over %@", tries,  
		  othercseq, checkseq);
	    
	    checkseq = othercseq;
	    [pick copyStateFromSource:other];
	  }

	  tries++;
	  if(tries==MAXTRIES){
	    st = STATE_DONE;
	  }
	  else{
	    [other copyStateFromSource:sdk];
	    [other setClues:[sender tag]];
	    st = STATE_CLUES;
	  }
	}

	[app runModalSession:findSession];
    } while(st!=STATE_DONE);

    [sdk copyStateFromSource:pick];
    [sdk cluesToPuzzle];

    [other dealloc]; [pick dealloc];

    [pi_panel orderOut:self];
    [app endModalSession:findSession];

    [[doc sudokuView] setNeedsDisplay:YES];
    [[doc sudokuView] display];
    [[[doc sudokuView] window] flushWindow];

    [doc updateChangeCount:NSChangeDone];

    return self;
}

#define BUTTON_HEIGHT 30

- makeInputPanel
{
  int m = NSTitledWindowMask;
  int x;
  float margin;
  NSButton *button;
  NSRect allframe ;
  NSRect frame = {{ 0, BUTTON_HEIGHT + DIGIT_FIELD_DIM},  { SDK_DIM, SDK_DIM} };
  sdkview  = [[SudokuView alloc] initWithFrame:frame];

  allframe = frame;
  allframe.size.height += BUTTON_HEIGHT + DIGIT_FIELD_DIM;

  enterPanel = 
      [[NSPanel alloc] initWithContentRect:allframe 
			styleMask:m                   
			backing: NSBackingStoreBuffered
                             defer:YES];
  [enterPanel setTitle:NSLocalizedString(@"Enter Sudoku", @"act of inserting")];
  [enterPanel setDelegate:self];

  [[enterPanel contentView] addSubview:sdkview];

  margin = (SDK_DIM - DIGIT_FIELD_DIM*10)/2;
  assert(margin>0);

  for(x=1; x<=10; x++){
      DigitSource *dgs =
	[[DigitSource alloc] 
	    initAtPoint:
		NSMakePoint(margin+(x-1)*DIGIT_FIELD_DIM, BUTTON_HEIGHT)
	    withDigit:x];
      [[enterPanel contentView] addSubview:dgs];
  }


  button = [NSButton new];
  [button setTitle:NSLocalizedString(@"Enter", @"inserting")];
  [button setTarget:self];
  [button setAction:@selector(actionEnter:)];

  [button setFrame:NSMakeRect(0, 0, SDK_DIM/3, BUTTON_HEIGHT)];
  
  [[enterPanel contentView] addSubview:button];

  button = [NSButton new];
  [button setTitle:NSLocalizedString(@"Reset", @"Button")];
  [button setTarget:self];
  [button setAction:@selector(actionReset:)];

  [button setFrame:NSMakeRect(SDK_DIM/3, 0, SDK_DIM/3, BUTTON_HEIGHT)];
  
  [[enterPanel contentView] addSubview:button];

  button = [NSButton new];
  [button setTitle:NSLocalizedString(@"Cancel", @"Button")];
  [button setTarget:self];
  [button setAction:@selector(actionCancel:)];

  [button setFrame:NSMakeRect(2*SDK_DIM/3, 0, SDK_DIM/3, BUTTON_HEIGHT)];
  
  [[enterPanel contentView] addSubview:button];

  [enterPanel setReleasedWhenClosed:NO];

  return self;
}

#define MAX_SOLVE_SECS 40

-(IBAction)actionEnter:(id)sender
{
  BOOL success;
  NSDocumentController *dc;
  Document *doc;
  Sudoku *sdk;
  Sudoku *user;
  NSPanel *pi_panel;
  NSProgressIndicator *pi;
  NSModalSession solveSession;
  float percent, dir;
  NSDate *end;

    [[NSApplication sharedApplication] stopModal];
    [enterPanel orderOut:self];

    [palette orderFront:self];

    dc = [NSDocumentController sharedDocumentController];
    [dc newDocument:self];

    doc = [dc currentDocument];
    sdk = [doc sudoku];
    user = [sdkview sudoku];

    [sdk copyStateFromSource:user];
    [sdk guessToClues];
    // [sdk cluesToPuzzle];

    pi_panel = [Controller prog_ind];
    pi = [pi_panel contentView];
    
    [pi_panel makeKeyAndOrderFront:self];

    solveSession = [[NSApplication sharedApplication] beginModalSessionForWindow:pi_panel];

    percent = 0;
    dir = 1;

    end = [NSDate dateWithTimeIntervalSinceNow:MAX_SOLVE_SECS];

    success = NO;
    do {
	int tick;
	NSDate *now;

	for(tick=0; tick<TICK_ITER; tick++){
	    [pi setDoubleValue:percent];
	    [pi display];

	    [[pi_panel contentView] setNeedsDisplay:YES];
	    [pi_panel flushWindow];

	    percent += TICK_STEP*dir;
	}
	if(percent==100.0){
	    dir = -1;
	}
	else if(percent==0.0){
	    dir = +1;
	}

	[[NSApplication sharedApplication] runModalSession:solveSession];

	now = [NSDate date];
	if([now laterDate:end]==now){
	    break;
	}

	success = [sdk find];
    } while(success==NO);

    [pi_panel orderOut:self];
    [[NSApplication sharedApplication] endModalSession:solveSession];

    if(success==NO){
	NSRunAlertPanel(NSLocalizedString(@"Solve failed", @"Alert"),
			NSLocalizedString(@"Could not solve Sudoku after %d sec(s).", @"Alert"),
			NSLocalizedString(@"Ok", @"Button"), nil, nil, MAX_SOLVE_SECS);
	[doc close];
    }
    else{
	[[doc sudokuView] setNeedsDisplay:YES];
	[[doc sudokuView] display];

	[[[doc sudokuView] window] flushWindow];

	[doc updateChangeCount:NSChangeDone];
    }
}

-(IBAction)actionReset:(id)sender
{
    [sdkview reset];
}

-(IBAction)actionCancel:(id)sender
{
    [[NSApplication sharedApplication]
        stopModal];
    [enterPanel orderOut:self];

    [palette orderFront:self];
}

-(IBAction)enterPuzzle:(id)sender
{
    [palette orderOut:self];

    [enterPanel center];
    [enterPanel makeKeyAndOrderFront:self];
    [[NSApplication sharedApplication]
	runModalForWindow:enterPanel];
}


- (void)applicationDidFinishLaunching:(NSNotification *)aNotification;
{
  NSDocumentController *dc = 
    [NSDocumentController sharedDocumentController];

  // Make the DocumentController the delegate of the application.
  // [NSApp setDelegate: dc];

  NSFileManager *fm = [NSFileManager defaultManager];
  NSArray *procArgs = [[NSProcessInfo processInfo] arguments];
  int arg;

  for(arg=1; arg<[procArgs count]; arg++){  // skip program name
    NSString *docFile = [procArgs objectAtIndex:arg];

    if([fm isReadableFileAtPath:docFile]==NO){
        NSLog(@"couldn't open %@ for reading", docFile);
    }
    else{
        NSArray *comps = [docFile pathComponents];
        if([[comps objectAtIndex:0] isEqualToString:@"/"]==NO){
            docFile = 
                [NSString stringWithFormat:@"%@/%@",
                          [fm currentDirectoryPath], docFile];
        }

        [dc openDocumentWithContentsOfFile:docFile display:YES];
    }
  }

  [self makeDigitPalette];
  [self makeInputPanel];
}

- makeDigitPalette
{
  int x, y;
  NSRect pbounds = 
    NSMakeRect(0, 0, 2*DIGIT_FIELD_DIM, 5*DIGIT_FIELD_DIM);

  NSRect 
    pframe =
    [NSWindow frameRectForContentRect:pbounds
	      styleMask:NSTitledWindowMask];

  palette =
    [[NSPanel alloc] initWithContentRect:pframe 
		      styleMask:NSTitledWindowMask                   
		      backing: NSBackingStoreBuffered
		      defer:YES];

  [palette setMinSize:pframe.size];
  [palette setMaxSize:pframe.size];

  [palette setTitle:NSLocalizedString(@"Digits", @"number components")];
  [palette setDelegate:self];

  [palette setFrameUsingName: @"SudokuDigitPalette"];
  [palette setFrameAutosaveName: @"SudokuDigitPalette"];


  for(x=0; x<2; x++){
    for(y=0; y<5; y++){
      DigitSource *dgs =
	[[DigitSource alloc] 
	  initAtPoint:
	    NSMakePoint(x*DIGIT_FIELD_DIM, (4-y)*DIGIT_FIELD_DIM)
	  withDigit:y*2+x+1];
      [[palette contentView] addSubview:dgs];
    }
  }

  [palette orderFrontRegardless];
  [palette makeKeyWindow];

  return self;
}

@end


