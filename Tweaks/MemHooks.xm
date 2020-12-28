#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>
#import "../Headers/MemHooks.h"
#import "../Headers/AeonLucid.h"
#import "../Headers/dobby.h"
#import "../Headers/FJPattern.h"
#include <sys/syscall.h>
#include <dlfcn.h>

@implementation MemHooks
- (NSDictionary *)getFJMemory {
	NSData *FJMemory = [NSData dataWithContentsOfFile:@"/var/mobile/Library/Preferences/FJMemory" options:0 error:nil];
	NSDictionary *DecryptedFJMemory = [NSJSONSerialization JSONObjectWithData:FJMemory options:0 error:nil];
	return DecryptedFJMemory;
}
@end

uint8_t RET[] = {
	0xC0, 0x03, 0x5F, 0xD6  //RET
};

uint8_t B8[] = {
	0x02, 0x00, 0x00, 0x14  //B #0x8
};

uint8_t SYSOpenBlock[] = {
	0xB0, 0x00, 0x80, 0xD2, //MOV X16, #5
	0x00, 0x00, 0x80, 0x52  //MOV X0, #0
};

uint8_t SYSAccessBlock[] = {
	0xB0, 0x00, 0x80, 0xD2,	//MOV X16, #21
	0x40, 0x00, 0x80, 0x52	//MOV X0, #2
};

uint8_t SYSAccessNOPBlock[] = {
	0xB0, 0x00, 0x80, 0xD2, //MOV X16, #21
	0x1F, 0x20, 0x03, 0xD5,  //NOP
	0x1F, 0x20, 0x03, 0xD5,  //NOP
	0x1F, 0x20, 0x03, 0xD5,  //NOP
	0x40, 0x00, 0x80, 0x52  //MOV X0, #2
};

void (*orig_subroutine)(void);
void nothing(void)
{
	;
}

void startHookTarget_lxShield(uint8_t* match) {
#if defined __arm64__
	hook_memory(match - 0x1C, RET, sizeof(RET));
#endif
}

void startHookTarget_AhnLab(uint8_t* match) {
#if defined __arm64__
	hook_memory(match, RET, sizeof(RET));
#endif
}

void startHookTarget_AhnLab2(uint8_t* match) {
#if defined __arm64__
	hook_memory(match - 0x10, RET, sizeof(RET));
#endif
}

void startHookTarget_AhnLab3(uint8_t* match) {
#if defined __arm64__
	hook_memory(match - 0x8, RET, sizeof(RET));
#endif
}

void startHookTarget_AhnLab4(uint8_t* match) {
#if defined __arm64__
	hook_memory(match - 0x10, RET, sizeof(RET));
#endif
}

void startHookTarget_AppSolid(uint8_t* match) {
#if defined __arm64__
	hook_memory(match, B8, sizeof(B8));
#endif
}

void startPatchTarget_SYSAccess(uint8_t* match) {
#if defined __arm64__
	hook_memory(match, SYSAccessBlock, sizeof(SYSAccessBlock));
#endif
}

void startPatchTarget_SYSAccessNOP(uint8_t* match) {
#if defined __arm64__
	hook_memory(match, SYSAccessNOPBlock, sizeof(SYSAccessNOPBlock));
#endif
}

void startPatchTarget_SYSOpen(uint8_t* match) {
#if defined __arm64__
	hook_memory(match, SYSOpenBlock, sizeof(SYSOpenBlock));
#endif
}

// ====== PATCH CODE ====== //
void SVC80_handler(RegisterContext *reg_ctx, const HookEntryInfo *info) {
#if defined __arm64__
	int syscall_num = (int)(uint64_t)reg_ctx->general.regs.x16;

	if(syscall_num == SYS_open || syscall_num == SYS_access || syscall_num == SYS_lstat64) {
		const char* path = (const char*)(uint64_t)(reg_ctx->general.regs.x0);
		NSString* path2 = [NSString stringWithUTF8String:path];
		if(![path2 hasSuffix:@"/sbin/mount"] && [FJPatternX isPathRestrictedForSymlink:path2]) {
			*(unsigned long *)(&reg_ctx->general.regs.x0) = (unsigned long long)"/XsF1re";
			NSLog(@"[FlyJB] Bypassed SVC #0x80 - num: %d, path: %s", syscall_num, path);
		}
		else {
			NSLog(@"[FlyJB] Detected SVC #0x80 - num: %d, path: %s", syscall_num, path);
		}
	}

	else {
		NSLog(@"[FlyJB] Detected Unknown SVC #0x80 number: %d", syscall_num);
	}
#endif
}

void startHookTarget_SVC80(uint8_t* match) {
#if defined __arm64__
	dobby_enable_near_branch_trampoline();
	DobbyInstrument((void *)(match), (DBICallTy)SVC80_handler);
	dobby_disable_near_branch_trampoline();
#endif
}

void loadSVC80MemHooks() {
#if defined __arm64__
	const uint8_t target[] = {
		0x01, 0x10, 0x00, 0xD4  //SVC #0x80
	};
	scan_executable_memory(target, sizeof(target), &startHookTarget_SVC80);
#endif
}

// ====== PATCH FROM FJMemory ====== //
void loadFJMemoryHooks() {
#if defined __arm64__
	NSString *bundleID = [[NSBundle mainBundle] bundleIdentifier];
	NSString *appVersion = [[NSBundle mainBundle] objectForInfoDictionaryKey:@"CFBundleShortVersionString"];
	NSDictionary *dict = [[[MemHooks alloc] init] getFJMemory];
	NSInteger dictAddrCount = [[[[dict valueForKeyPath:bundleID] objectForKey:appVersion] objectForKeyedSubscript:@"addr"] count];
	if(dictAddrCount) {
		for(int i=0; i < dictAddrCount; i++)
		{
			NSString* dict_addr = [[[[dict valueForKeyPath:bundleID] objectForKey:appVersion] objectForKeyedSubscript:@"addr"] objectAtIndex:i];
			NSString* dict_instr = [[[[dict valueForKeyPath:bundleID] objectForKey:appVersion] objectForKeyedSubscript:@"instr"] objectAtIndex:i];
			NSLog(@"[FlyJB] bundleID = %@, dict_addr = %@, dict_instr = %@", bundleID, dict_addr, dict_instr);
			writeData(strtoull(dict_addr.UTF8String, NULL, 0), strtoull(dict_instr.UTF8String, NULL, 0));
		}
	}
#endif
}

// ====== 하나멤버스 무결성 복구 ====== //
%group FJMemoryIntegrityRecoverHMS
%hook NSFileManager
- (BOOL)fileExistsAtPath: (NSString *)path {
#if defined __arm64__
	if([path hasSuffix:@"/com.vungle/userInfo"]) {
		NSString *bundleID = [[NSBundle mainBundle] bundleIdentifier];
		NSString *appVersion = [[NSBundle mainBundle] objectForInfoDictionaryKey:@"CFBundleShortVersionString"];
		NSDictionary *dict = [[[MemHooks alloc] init] getFJMemory];
		NSInteger dictInstrOrigCount = [[[[dict valueForKeyPath:bundleID] objectForKey:appVersion] objectForKeyedSubscript:@"instr_orig"] count];
		if(dictInstrOrigCount) {
			for(int i=0; i < dictInstrOrigCount; i++)
			{
				NSString* dict_addr = [[[[dict valueForKeyPath:bundleID] objectForKey:appVersion] objectForKeyedSubscript:@"addr"] objectAtIndex:i];
				NSString* dict_instrOrig = [[[[dict valueForKeyPath:bundleID] objectForKey:appVersion] objectForKeyedSubscript:@"instr_orig"] objectAtIndex:i];
				writeData(strtoull(dict_addr.UTF8String, NULL, 0), strtoull(dict_instrOrig.UTF8String, NULL, 0));
			}
		}
	}
#endif
	return %orig;
}
%end
%end

// ====== 롯데안심인증 무결성 복구 ====== //
%group FJMemoryIntegrityRecoverLMP
%hook XASAskJobs
+(int)updateCheck {
#if defined __arm64__
	NSString *bundleID = [[NSBundle mainBundle] bundleIdentifier];
	NSString *appVersion = [[NSBundle mainBundle] objectForInfoDictionaryKey:@"CFBundleShortVersionString"];
	NSDictionary *dict = [[[MemHooks alloc] init] getFJMemory];
	NSInteger dictInstrOrigCount = [[[[dict valueForKeyPath:bundleID] objectForKey:appVersion] objectForKeyedSubscript:@"instr_orig"] count];
	if(dictInstrOrigCount) {
		for(int i=0; i < dictInstrOrigCount; i++)
		{
			NSString* dict_addr = [[[[dict valueForKeyPath:bundleID] objectForKey:appVersion] objectForKeyedSubscript:@"addr"] objectAtIndex:i];
			NSString* dict_instrOrig = [[[[dict valueForKeyPath:bundleID] objectForKey:appVersion] objectForKeyedSubscript:@"instr_orig"] objectAtIndex:i];
			writeData(strtoull(dict_addr.UTF8String, NULL, 0), strtoull(dict_instrOrig.UTF8String, NULL, 0));
		}
	}
#endif
	return 121;
}
%end
%end

void loadFJMemoryIntegrityRecover() {
	NSString *bundleID = [[NSBundle mainBundle] bundleIdentifier];
	if([bundleID isEqualToString:@"com.hana.hanamembers"]) {
		%init(FJMemoryIntegrityRecoverHMS);
	}
	if([bundleID isEqualToString:@"com.lottecard.mobilepay"]) {
		%init(FJMemoryIntegrityRecoverLMP);
	}
}

// ====== PATCH SYMBOL FROM FJMemory ====== //
void loadFJMemorySymbolHooks() {
	NSString *bundleID = [[NSBundle mainBundle] bundleIdentifier];
	NSString *appVersion = [[NSBundle mainBundle] objectForInfoDictionaryKey:@"CFBundleShortVersionString"];
	NSDictionary *dict = [[[MemHooks alloc] init] getFJMemory];
	NSInteger SymbolCount = [[[[dict valueForKeyPath:bundleID] objectForKey:appVersion] objectForKeyedSubscript:@"symbol"] count];
	for(int i=0; i < SymbolCount; i++)
	{
		NSString* dict_Symbol = [[[[dict valueForKeyPath:bundleID] objectForKey:appVersion] objectForKeyedSubscript:@"symbol"] objectAtIndex:i];
		const char *dict_Symbol_cs = [dict_Symbol cStringUsingEncoding:NSUTF8StringEncoding];
		MSHookFunction(MSFindSymbol(NULL, dict_Symbol_cs), (void *)nothing, (void **)&orig_subroutine);
	}
}

void opendir_handler(RegisterContext *reg_ctx, const HookEntryInfo *info) {
	#if defined __arm64__
	const char* path = (const char*)(uint64_t)(reg_ctx->general.regs.x0);
	NSString* path2 = [NSString stringWithUTF8String:path];

	if([FJPatternX isPathRestricted:path2]) {
		NSLog(@"[FlyJB] Bypassed opendir path = %s", path);
		unsigned long fileValue = 0;
		__asm __volatile("mov x0, %0" :: "r" ("/XsF1re_Bypass!@#"));         //path
		__asm __volatile("mov %0, x0" : "=r" (fileValue));
		*(unsigned long *)(&reg_ctx->general.regs.x0) = fileValue;
	}
	else {
		NSLog(@"[FlyJB] Detected opendir path = %s", path);
	}

	#endif
}

void loadOpendirMemHooks() {
#if defined __arm64__
	//dobby_enable_near_branch_trampoline();
	DobbyInstrument(dlsym((void *)RTLD_DEFAULT, "opendir"), (DBICallTy)opendir_handler);
	//dobby_disable_near_branch_trampoline();
#endif
}
