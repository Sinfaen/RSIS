#ifndef __RSIS_TYPES_HXX__
#define __RSIS_TYPES_HXX__

extern "C" {

/**
 * RSIS states. Julia side must match
 */
enum class RSISState : int {
    NOSTATE = 0,
    CONFIG,
    INIT,
    READY,
    PAUSE,
    RUN,
    END
};

/**
 * RSIS command status. Julia side must match
 */
enum class RSISCmdStat : int {
    OK = 0,
    ERR
};

}

#endif
