#import "include/CSMC_T2.h"

@implementation CSMC_T2

+ (kern_return_t)open:(io_connect_t *)connection {
    io_service_t service = IOServiceGetMatchingService(kIOMainPortDefault, IOServiceMatching("AppleSMC"));
    if (service == 0) return kIOReturnNoDevice;
    
    kern_return_t result = IOServiceOpen(service, mach_task_self(), 0, connection);
    IOObjectRelease(service);
    return result;
}

+ (kern_return_t)close:(io_connect_t)connection {
    return IOServiceClose(connection);
}

+ (kern_return_t)write:(io_connect_t)connection key:(uint32_t)key type:(uint32_t)type data:(uint8_t *)data size:(uint32_t)size {
    SMCParamStruct80 input;
    SMCParamStruct80 output;
    
    memset(&input, 0, sizeof(SMCParamStruct80));
    memset(&output, 0, sizeof(SMCParamStruct80));
    
    input.key = key;
    input.dataSize = size;
    input.dataType = type;
    input.command = 6; // SMC_CMD_WRITE_KEY
    memcpy(input.data, data, size); 
    
    size_t inputSize = sizeof(SMCParamStruct80);
    size_t outputSize = sizeof(SMCParamStruct80);
    
    return IOConnectCallStructMethod(connection, 2, &input, inputSize, &output, &outputSize);
}

@end
