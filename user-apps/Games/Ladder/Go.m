#include "Go.h"
#include "Player.h"

#include <Foundation/NSFileHandle.h>

NSString * GoStoneNotification = @"GoStoneNotification";

@implementation Stone

- (NSString*) description
{
	return [NSString stringWithFormat: @"<%@: %@>",
		   NSStringFromClass([self class]), _colorType == BlackPlayerType?@"Black":@"White"];
}


+ (Stone *) stoneWithColorType:(PlayerColorType)colorType
{
	id stone = AUTORELEASE([self new]);
	[stone setColorType:colorType];
	return stone;
}


- (void) setTurnNumber:(unsigned int) num
{
	turnno = num;
}

- (unsigned int) turnNumber
{
	return turnno;
}

- (PlayerColorType) colorType
{
	return _colorType;
}

- (void) setColorType:(PlayerColorType)newColorType
{
	_colorType = newColorType;
}

- (void) setOwner:(Go *)owner
{
	__owner = owner;
}

- (Go *) owner
{
	return __owner;
}

- (GoLocation) location
{
	if (__owner)
	{
		return [__owner locationForStone:self];
	}
	else
	{
		return GoNoLocation;
	}
}

@end

@implementation GoTurn
@end

@class StoneUI;


@interface Go (Private)
- (void) _setupGNUGo;
@end


@implementation Go

/* FIXME change this to dictionary */
static NSString *columnstr[] = {@"A",@"B",@"C",@"D",@"E",@"F",@"G",@"H",@"J",@"K",@"L",@"M",@"N",@"O",@"P",@"Q",@"R",@"S",@"T"};

static NSString * __string_for_go_location(GoLocation loc)
{
	if (loc.row == 0 || loc.column == 0)
	{
		return @"pass";
	}
	return [NSString stringWithFormat:@"%@%d",
		   columnstr[loc.column-1],
		   loc.row];
}

static GoLocation __go_location_for_string(NSString *str)
{
	GoLocation retloc;
	int i;

	if (str == nil || [str length] < 2 || [str isEqualToString:@"pass"])
	{
		return GoNoLocation;
	}

	NSString *substr = [str substringToIndex:1];

	for (i=0;i<19;i++)
	{
		if ([substr caseInsensitiveCompare:columnstr[i]] == NSOrderedSame)
		{
			retloc.column = i + 1;
			break;
		}
	}
	substr = [str substringFromIndex:1];
	retloc.row = [substr intValue];

	return retloc;
}

static BOOL __check_state(NSString *str)
{
	if ([str characterAtIndex:0] == '=')
	{
		return YES;
	}
	return NO;
}


#if 0 
- (void) awakeFromNib
{
//	[self setHandicap:100];

	/*
	int r,c;

	[self setBoardSize:5 + random()%15];
	[self setStoneClass:[StoneUI class]];

	for (r = 1; r <= size; r++)
	for (c = 1; c <= size; c++)
	{
		if (random()%2)
		{
			[self setStoneWithColorType:random()%2
							 atLocation:MakeGoLocation(r,c)];
		}
	}
	*/

}
#endif

/*
- (id) retain
{
	NSDebugLog(@"retain Go %d",[self retainCount]);
	return [super retain];
}

- (void) release
{
	NSDebugLog(@"release Go %d",[self retainCount]);
	[super release];
}
*/

- (id) init
{
//	NSDebugLog(@"init %d",[self retainCount]);
	stoneClass = [Stone class];
	turn = BlackPlayerType;
	[self setBoardSize:19];
	[self _setupGNUGo];
	return self;
}


- (NSString *) runGTPCommand:(NSString *)command
{
	NSString *str;
	NSFileHandle *fh  = [_commandPipe fileHandleForWriting];
	NSData *data = [[command stringByAppendingString:@"\n"] dataUsingEncoding:NSASCIIStringEncoding];

	[fh writeData:data];

	fh = [_eventPipe fileHandleForReading];

	str = @"";

	while ((data = [fh availableData]))
	{
		const char *bytes = [data bytes];
		unsigned offset = [data length];
		str = [str stringByAppendingString:
			AUTORELEASE([[NSString alloc] initWithData:data
											  encoding:NSASCIIStringEncoding])];
		if (bytes[offset - 2] == 0x0A && bytes[offset - 1] == 0x0A)
		{
			break;
		}
	}

	return str;
}


- (void) turnBegin:(NSCalendarDate *)turnDate
{
	/* if no dict */
	PlayerColorType newTurn;

	if (turnDate == nil)
	{
		turnDate = [NSCalendarDate calendarDate];
	}

	if (_gameBeginDate == nil)
	{
		_turnBeginDate = [turnDate copy];
		_gameBeginDate = [turnDate copy];
	}

	timeUsed[turn] = timeUsed[turn] + [turnDate timeIntervalSinceDate:_turnBeginDate];

	ASSIGN(_turnBeginDate, turnDate);

	if (turn == WhitePlayerType)
	{
		turn = BlackPlayerType;
	}
	else
	{
		turn = WhitePlayerType;
	}

	_turnNumber++;

	/* notify the system that new turn has begun */
	NSMutableDictionary * dict;
	dict = [NSMutableDictionary dictionary];

	[dict setObject:turn == BlackPlayerType?@"BlackStone":@"WhiteStone"
			 forKey:@"CurrentTurn"];

	[[NSNotificationCenter defaultCenter] postNotificationName:GameTurnDidBeginNotification
														object:self
													  userInfo:dict];

}

- (void) newTurnForPlayerWithColorType:(PlayerColorType) playerColorType
{


	if (isPause)
	{
		[self continue];
	}

		/*
		[dict setObject:stone
				 forKey:@"Stone"];
				 */
}


- (void) dealloc
{
	NSDebugLog(@"Go %@ dealloc",self);
	[self setBoardSize:1];
	free(_boardTable);
	RELEASE(_players[BlackPlayerType]);
	RELEASE(_players[WhitePlayerType]);
	RELEASE(_startTurn);
	RELEASE(_gameBeginDate);
	RELEASE(_turnBeginDate);
	[_gnugo terminate];
	RELEASE(_gnugo);

	[super dealloc];
}

- (void) setStoneClass:(Class)aClass
{
	stoneClass = aClass;
}

- (void) _clearTable
{
	int i,j,offset;

	if (_boardTable != NULL)
	{
		for (i = 0; i < size; i++)
		{
			for (j = 0; j < size; j++)
			{
				offset = i * size + j;
				if (_boardTable[offset] != nil)
				{
					DESTROY(_boardTable[offset]);
				}
			}
		}
	}
}

- (void) clearBoard
{
	[self _clearTable];
	NSAssert(__check_state([self runGTPCommand:@"clear_board"]), @"clear board fail");
}

- (void) setBoardSize:(unsigned int)newSize;
{
	int i,j;

	if (_boardTable != NULL)
	{
		[self clearBoard];
		free(_boardTable);
	}

	size = newSize;

	_boardTable = malloc(sizeof(id) * size * size);
	bzero(_boardTable, sizeof(id) * size * size);

}

- (unsigned int) boardSize;
{
	return size;
}

/*
- (void) setHandicap:(unsigned int)handicap
{
	NSAssert(_turnNumber == 0, @"Set handicap during the game");
	_handicapLeft = handicap;
}
*/

- (void) _setupGNUGo
{
	if (_gnugo == nil)
	{
		ASSIGN(_gnugo, [[NSTask alloc] init]);
		ASSIGN(_eventPipe, [NSPipe pipe]);
		ASSIGN(_commandPipe, [NSPipe pipe]);
		/*

		[[NSNotificationCenter defaultCenter] addObserver:self
												 selector:@selector(GNUGoEvent:)
													 name:NSFileHandleDataAvailableNotification
												   object:[_eventPipe fileHandleForReading]];
		[[_eventPipe fileHandleForReading] waitForDataInBackgroundAndNotify];
		*/

		[_gnugo setStandardOutput:_eventPipe];
		[_gnugo setStandardInput:_commandPipe];
		[_gnugo setLaunchPath:@"gnugo"];
		[_gnugo setArguments:[NSArray arrayWithObjects:@"--mode",@"gtp",nil]];
		[_gnugo launch];
		NSDebugLog(@"launch gnugo");

	}
}

- (void) _syncBoardWithGNUGo
{
	NSString *str;
	NSEnumerator *en;
	NSArray *items;
	GoLocation loc;
	id *newTable;
	id stone;
	int offset,i;
	NSString *cmdList[] = {@"list_stones black",@"list_stones white"};

	newTable = malloc(sizeof(id) * size * size);
	bzero(newTable, sizeof(id) * size * size);

	for (i = 0; i < 2; i++)
	{
		str = [self runGTPCommand:cmdList[i]];
		if (__check_state(str))
		{
			str = [str substringWithRange:NSMakeRange(2,[str length]-4)];
			items = [str componentsSeparatedByString:@" "];
			en = [items objectEnumerator];
			while ((str = [en nextObject]))
			{
				loc = __go_location_for_string(str);

				if (GoIsLocation(loc))
				{
					offset = (loc.row - 1) * size + (loc.column - 1);
					stone = [self stoneAtLocation:loc];
					if (stone)
					{
						ASSIGN(newTable[offset],stone);
					}
					else
					{
						stone = [stoneClass stoneWithColorType:i];
						ASSIGN(newTable[offset],stone);
						if (stone != nil && offset >= 0)
						{
							[stone setOwner:self];
							[(id<GameTurn>)stone setTurnNumber: -1];
						}
					}
				}
			}
		}
	}

	[self _clearTable];
	free(_boardTable);
	_boardTable = newTable;
}

- (void) setStone:(id <Stone>) stone
	   atLocation:(GoLocation) location
			 date:(NSCalendarDate *)turnTime
{
	int offset = (location.row - 1) * size + (location.column - 1);

	NSString *cmdString;

	cmdString = [NSString stringWithFormat:@"play %@ %@",[stone colorType] == BlackPlayerType?@"black":@"white",__string_for_go_location(location)];


	if (__check_state([self runGTPCommand:cmdString]) == NO)
	{
		NSDebugLog(@"set stone fail");
		NSDebugLog([self runGTPCommand:@"showboard"]);
		return;
	}
	else
	{
	//	NSDebugLog([self runGTPCommand:@"showboard"]);
	}

	//timeUsed[turn] = timeUsed[turn] + [turnTime timeIntervalSinceDate:_turnBeginDate];

	if (stone != nil && offset >= 0)
	{
		[stone setOwner:self];
		[stone setTurnNumber:_turnNumber];
		ASSIGN(_boardTable[offset], stone);
		[self _syncBoardWithGNUGo];

		NSMutableDictionary *dict = [NSMutableDictionary dictionary];
		[dict setObject:stone
				 forKey:@"Stone"];
		[[NSNotificationCenter defaultCenter] postNotificationName:GoStoneNotification
															object:self
														  userInfo:dict];
	}
	else
	{
		[[NSNotificationCenter defaultCenter] postNotificationName:GoStoneNotification
															object:self
														  userInfo:nil];
	}


}

- (void) setStone:(id <Stone>) stone
	   atLocation:(GoLocation) location
{
	NSDebugLog(@"%d",[stone colorType]);
	[self setStone:stone
		atLocation:location
			  date:[NSCalendarDate calendarDate]];
}

- (void) setStoneWithColorType:(PlayerColorType) aColorType
					atLocation:(GoLocation) location
{
	[self setStone:[stoneClass stoneWithColorType:aColorType]
		atLocation:location];
}

- (void) putStoneAtLocation:(GoLocation) location
{
//	NSDebugLog(@"TURN %d",turn);
	if (location.row == 0)
	{
		return;
	}
	[self setStoneWithColorType:turn
					 atLocation:location];
}

- (void) passTurn
{
	[self turnBegin:nil];
}


- (unsigned long) turnNumber
{
	return _turnNumber;
}

/* for undoing */
- (void) setTurnNumber:(unsigned long)turnNumber
{
	_turnNumber = turnNumber;
}

- (id *) board
{
	return _boardTable;
}

- (Stone *) stoneAtLocation:(GoLocation) location
{
	if (location.row > size || location.column > size)
	{
		return nil;
	}

	return _boardTable[(location.row - 1) * size + (location.column - 1)];
}

- (GoLocation) locationForStone:(id <Stone>) stone
{
	int i,j;
	if (_boardTable != NULL)
	{
		for (i = 0; i < size; i++)
		{
			for (j = 0; j < size; j++)
			{
				int offset;

				offset = i * size + j;
				if (_boardTable[offset] == stone)
				{
					return MakeGoLocation(i+1, j+1);
				}
			}
		}
	}

	return GoNoLocation;
}

- (PlayerColorType) turn
{
	return turn;
}

- (void) setBlackPlayer:(Player *)blackPlayer
			whitePlayer:(Player *)whitePlayer
{
	ASSIGN(_players[BlackPlayerType], blackPlayer);
	ASSIGN(_players[WhitePlayerType], whitePlayer);
}

- (void) setTimeUsed:(NSTimeInterval) time
forPlayerWithColorType:(PlayerColorType) playerColorType
{
	timeUsed[playerColorType] = time;
}

- (NSTimeInterval) timeUsedForPlayerWithColorType:(PlayerColorType) playerColorType
{
	return timeUsed[playerColorType];
}

- (void) pause
{
	isPause = YES;
	NSCalendarDate * turnTime = [NSCalendarDate calendarDate];

	timeUsed[turn] = timeUsed[turn] + [turnTime timeIntervalSinceDate:_turnBeginDate];
}

- (void) continue
{
	NSCalendarDate * turnTime = [NSCalendarDate calendarDate];
	isPause = NO;
	ASSIGN(_turnBeginDate, turnTime);
}

- (NSCalendarDate *) gameBeginDate
{
	return _gameBeginDate;
}

- (NSCalendarDate *) turnBeginDate
{
	return _turnBeginDate;
}

- (BOOL) printSGFToFile:(NSString *)path
{
	if (__check_state([self runGTPCommand:[NSString stringWithFormat:@"printsgf %@",path]]) == NO)
	{
		NSDebugLog(@"Cannnot execute printsgf on path %@",path);
		return NO;
	}
	return YES;
}

- (BOOL) loadSGFFile:(NSString *)path
{
	NSDebugLog(@"will load %@",path);
	if (__check_state([self runGTPCommand:[NSString stringWithFormat:@"loadsgf %@",path]]) == NO)
	{
		NSDebugLog(@"Cannnot execute loadsgf on path %@",path);
		return NO;
	}
	[self _syncBoardWithGNUGo];

	NSDebugLog(@"success");
	return YES;
}

@end
