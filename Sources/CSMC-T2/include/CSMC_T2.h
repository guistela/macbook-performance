#ifndef CSMC_T2_H
#define CSMC_T2_H

#import <Foundation/Foundation.h>
#import <IOKit/IOKitLib.h>

#pragma pack(push, 1)
typedef struct {
    uint32_t key;           // 0
    uint32_t padding1[5];   // 4 (Total 20 bytes)
    uint32_t dataSize;      // 24
    uint32_t dataType;      // 28
    uint8_t  data[32];      // 32
    uint8_t  command;       // 64
    uint8_t  padding3[3];   // 65
    uint8_t  result;        // 68
    uint8_t  padding4[3];   // 69
    uint8_t  padding5[8];   // 72 (Total 80 bytes)
} SMCParamStruct80;
#pragma pack(pop)

@interface CSMC_T2 : NSObject

+ (kern_return_t)open:(io_connect_t *)connection;
+ (kern_return_t)close:(io_connect_t)connection;
+ (kern_return_t)write:(io_connect_t)connection key:(uint32_t)key type:(uint32_t)type data:(uint8_t *)data size:(uint32_t)size;

@end

#endif
