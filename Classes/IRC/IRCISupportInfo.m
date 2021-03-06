// LimeChat is copyrighted free software by Satoshi Nakagawa <psychs AT limechat DOT net>.
// You can redistribute it and/or modify it under the terms of the GPL version 2 (see the file GPL.txt).

#import "IRCISupportInfo.h"
#import "NSStringHelper.h"
#import "NSDictionaryHelper.h"


#define ISUPPORT_SUFFIX	@" are supported by this server"
#define OP_VALUE		100


@interface IRCISupportInfo (Private)
- (void)setValue:(int)value forMode:(unsigned char)m;
- (int)valueForMode:(unsigned char)m;
- (BOOL)hasParamForMode:(unsigned char)m plus:(BOOL)plus;
- (void)parsePrefix:(NSString*)s;
- (void)parseChanmodes:(NSString*)s;
@end


@implementation IRCISupportInfo

@synthesize nickLen;
@synthesize modesCount;
@synthesize prefixesMap;
@synthesize modesMap;


- (id)init
{
	if (self = [super init]) {
		[self reset];
	}
	return self;
}

- (void)dealloc
{
	[modesMap release];
	[super dealloc];
}

- (void)reset
{
	memset(modes, 0, MODES_SIZE);
	nickLen = 9;
	modesCount = 3;
	
	[self setValue:OP_VALUE forMode:'o'];
	[self setValue:OP_VALUE forMode:'h'];
	[self setValue:OP_VALUE forMode:'v'];
	[self setValue:1 forMode:'b'];
	[self setValue:1 forMode:'e'];
	[self setValue:1 forMode:'I'];
	[self setValue:1 forMode:'R'];
	[self setValue:2 forMode:'k'];
	[self setValue:3 forMode:'l'];
	[self setValue:4 forMode:'i'];
	[self setValue:4 forMode:'m'];
	[self setValue:4 forMode:'n'];
	[self setValue:4 forMode:'p'];
	[self setValue:4 forMode:'s'];
	[self setValue:4 forMode:'t'];
	[self setValue:4 forMode:'a'];
	[self setValue:4 forMode:'q'];
	[self setValue:4 forMode:'r'];
	
	prefixesMap = [[NSMutableDictionary alloc] initWithCapacity:5];
	// The problem is that with a dictionary I cannot make the following rule:
	// if q and not o then still o
	// NOTE what if I don't need to?
	[prefixesMap setObject:@"q" forKey:@"~"];
	[prefixesMap setObject:@"o" forKey:@"@"];
	[prefixesMap setObject:@"o" forKey:@"&"];
	[prefixesMap setObject:@"h" forKey:@"%"];
	[prefixesMap setObject:@"v" forKey:@"+"];

	modesMap = [[NSMutableDictionary alloc] initWithCapacity:4];
	[modesMap setObject:@"~" forKey:@"q"];
	[modesMap setObject:@"@" forKey:@"o"];
	[modesMap setObject:@"%" forKey:@"h"];
	[modesMap setObject:@"+" forKey:@"v"];
}

- (void)update:(NSString*)str
{
	if ([str hasSuffix:ISUPPORT_SUFFIX]) {
		str = [str substringToIndex:str.length - [ISUPPORT_SUFFIX length]];
	}
	
	NSArray* ary = [str split:@" "];
	
	for (NSString* s in ary) {
		NSRange r = [s rangeOfString:@"="];
		if (r.location != NSNotFound) {
			NSString* key = [[s substringToIndex:r.location] uppercaseString];
			NSString* value = [s substringFromIndex:NSMaxRange(r)];
			if ([key isEqualToString:@"PREFIX"]) {
				[self parsePrefix:value];
			}
			else if ([key isEqualToString:@"CHANMODES"]) {
				[self parseChanmodes:value];
			}
			else if ([key isEqualToString:@"NICKLEN"]) {
				nickLen = [value intValue];
			}
			else if ([key isEqualToString:@"MODES"]) {
				modesCount = [value intValue];
			}
		}
	}
}

- (NSArray*)parseMode:(NSString*)str
{
	NSMutableArray* ary = [NSMutableArray array];
	NSMutableString* s = [[str mutableCopy] autorelease];
	BOOL plus = NO;
	
	while (!s.isEmpty) {
		NSString* token = [s getToken];
		if (token.isEmpty) break;
		UniChar c = [token characterAtIndex:0];
		
		if (c == '+' || c == '-') {
			plus = c == '+';
			token = [token substringFromIndex:1];
			
			int len = token.length;
			for (int i=0; i<len; i++) {
				c = [token characterAtIndex:i];
				switch (c) {
					case '-':
						plus = NO;
						break;
					case '+':
						plus = YES;
						break;
					default:
					{
						int v = [self valueForMode:c];
						if (v == OP_VALUE) {
							// op
							IRCModeInfo* m = [IRCModeInfo modeInfo];
							m.mode = c;
							m.plus = plus;
							m.param = [s getToken];
							m.op = YES;
							[ary addObject:m];
						}
						else if ([self hasParamForMode:c plus:plus]) {
							// 1 param
							IRCModeInfo* m = [IRCModeInfo modeInfo];
							m.mode = c;
							m.plus = plus;
							m.param = [s getToken];
							[ary addObject:m];
						}
						else {
							// simple mode
							IRCModeInfo* m = [IRCModeInfo modeInfo];
							m.mode = c;
							m.plus = plus;
							m.simpleMode = (v == 4);
							[ary addObject:m];
						}
						break;
					}
				}
			}
		}
	}
	
	return ary;
}

- (BOOL)hasParamForMode:(unsigned char)m plus:(BOOL)plus
{
	switch ([self valueForMode:m]) {
		case 0: return NO;
		case 1: return YES;
		case 2: return YES;
		case 3: return plus;
		case OP_VALUE: return YES;
		default: return NO;
	}
}

- (void)parsePrefix:(NSString*)str
{
	if ([str hasPrefix:@"("]) {
		NSRange r = [str rangeOfString:@")"];
		if (r.location != NSNotFound) {
			NSString *ms = [str substringWithRange:NSMakeRange(1, r.location - 1)];
			int len = ms.length;
			// XXX Can easily go out of range and then bad things may happen
			NSString *ps = [str substringWithRange:NSMakeRange(r.location+1, len)];
			for (int i=0; i<len; i++) {
				UniChar m = [ms characterAtIndex:i];
				[self setValue:OP_VALUE forMode:m];
				UniChar p = [ps characterAtIndex:i];
//				[prefixesMap setObject:[NSString stringWithFormat:@"%c", m]
//								forKey:[NSString stringWithFormat:@"%c", p]];
//				[modesMap setObject:[NSString stringWithFormat:@"%c", p]
//							 forKey:[NSString stringWithFormat:@"%c", m]];
				NSString *str_m = [NSString stringWithCharacters:&m length:1];
				NSString *str_p = [NSString stringWithCharacters:&p length:1];
				[prefixesMap setObject:str_m forKey:str_p];
				[modesMap setObject:str_p forKey:str_m];
				//NSLog(@"%@", [NSString stringWithFormat:@"[parsePrefix] mode=%@, prefix=%@", str_m, str_p]);
			}
		}
	}
}

- (void)parseChanmodes:(NSString*)str
{
	NSArray* ary = [str split:@","];
	
	int count = ary.count;
	for (int i=0; i<count; i++) {
		NSString* s = [ary objectAtIndex:i];
		int len = s.length;
		for (int j=0; j<len; j++) {
			UniChar c = [s characterAtIndex:j];
			[self setValue:i+1 forMode:c];
		}
	}
}

- (void)setValue:(int)value forMode:(unsigned char)m
{
	if ('a' <= m && m <= 'z') {
		int n = m - 'a';
		modes[n] = value;
	}
	else if ('A' <= m && m <= 'Z') {
		int n = m - 'A' + 26;
		modes[n] = value;
	}
}

- (int)valueForMode:(unsigned char)m
{
	if ('a' <= m && m <= 'z') {
		int n = m - 'a';
		return modes[n];
	}
	else if ('A' <= m && m <= 'Z') {
		int n = m - 'A' + 26;
		return modes[n];
	}
	return 0;
}

- (UniChar)userModeByPrefix:(NSString*)p
{
	//NSString *key;
//	for (key in prefixesMap) {
//		NSLog(@"%@", [NSString stringWithFormat:@"userModeByPrefix: prefixesMap[%@]=%@", key, [prefixesMap objectForKey:key]]);
//	}
//	for (key in modesMap) {
//		NSLog(@"%@", [NSString stringWithFormat:@"userModeByPrefix: modesMap[%@]=%@", key, [modesMap objectForKey:key]]);
//	}
	NSString *obj = [prefixesMap objectForKey:p];
	if ((obj != nil) && obj.length)
		return (UniChar)[obj characterAtIndex:0];
	return nil;
}


@end


@implementation IRCModeInfo

@synthesize mode;
@synthesize plus;
@synthesize op;
@synthesize simpleMode;
@synthesize param;

+ (IRCModeInfo*)modeInfo
{
	return [[IRCModeInfo new] autorelease];
}

- (void)dealloc
{
	[param release];
	[super dealloc];
}

@end
