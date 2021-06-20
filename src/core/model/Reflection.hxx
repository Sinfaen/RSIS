
#ifndef __REFLECTION_HXX__
#define __REFLECTION_HXX__

#include <cstddef>
#include <functional>
#include <vector>

namespace RSIS {
namespace Reflection {

/**
 * Typedef for class registration callback
 */
typedef std::function<void(char*)> RegisterClass;

/**
 * Typedef for field registration callback
 */
typedef std::function<void(char*, char*, char*, std::vector<int>, size_t, bool)> RegisterField;

/**
 * Typedef for removing metadata callback
 */
typedef std::function<void(char*)> DeleteClass;

}
}

#endif
