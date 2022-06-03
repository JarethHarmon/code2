#include <Godot.hpp>
#include <Node.hpp>
#include <memory>
#include <set>
#include <io.h>
#include <string>
#include <cstring>
#include "komihash.h"

namespace godot 
{
class Gob : public Node
{
    GODOT_CLASS(Gob, Node)

public:
    static void _register_methods()
    {
        register_method("get_unsigned_komi_hash", &Gob::get_unsigned_komi_hash);
        register_method("get_signed_komi_hash", &Gob::get_signed_komi_hash);
    }

    void _init()
    {
    }

    // return as 64bit int (will be automatically signed)
    //      + slightly faster without string conversions
    //      + should still be just as accurate (at least within the confines of the program)
    //      + can process and store with Godot (meaning should result in less storage space (64 bits vs 256bits or 64bytes (if stored as string))
    //      - may not be accurate/safe to auto-convert between signed and unsigned int
    //      - my hashes would not be automatically compatible with those from a proper implementation

    String get_unsigned_komi_hash(String file_path)
    {
        FILE *fptr;
        char* buffer;
        long filelen;

        fptr = fopen(file_path.utf8().get_data(), "rb");
        fseek(fptr, 0, SEEK_END);
        filelen = ftell(fptr);
        rewind(fptr);

        buffer = (char*)malloc(filelen * sizeof(char));
        fread(buffer, filelen, 1, fptr);
        fclose(fptr);

        uint64_t kh = komihash(buffer, filelen, 0);
        std::free(buffer);
        return String(std::to_string(kh).c_str());
    }

    uint64_t get_signed_komi_hash(String file_path) {
        FILE* fptr;
        char* buffer;
        long filelen;

        fptr = fopen(file_path.utf8().get_data(), "rb");
        fseek(fptr, 0, SEEK_END);
        filelen = ftell(fptr);
        rewind(fptr);

        buffer = (char*)malloc(filelen * sizeof(char));
        fread(buffer, filelen, 1, fptr);
        fclose(fptr);

        uint64_t kh = komihash(buffer, filelen, 0);
        std::free(buffer);
        return kh;
    }

};

extern "C" void GDN_EXPORT godot_gdnative_init(godot_gdnative_init_options *o) 
{
    godot::Godot::gdnative_init(o);
}

extern "C" void GDN_EXPORT godot_gdnative_terminate(godot_gdnative_terminate_options *o) 
{
    godot::Godot::gdnative_terminate(o);
}

extern "C" void GDN_EXPORT godot_nativescript_init(void *handle) 
{
    godot::Godot::nativescript_init(handle);
    godot::register_class<godot::Gob>();
}
}
