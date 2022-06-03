#include <Godot.hpp>
#include <Node.hpp>
#include <memory>
#include <set>
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

    String get_unsigned_komi_hash(String file_path)
    {
        FILE* fptr;
        char* buffer;
        long filelen;

        // this is why I don't like c++: the official method of using ccs does not work at all, and instead you have to use setlocale()
        setlocale(LC_ALL, ".65001");
        fptr = fopen(file_path.utf8().get_data(), "rb");
        //fptr = fopen(file_path.utf8().get_data(), "rb, ccs=UTF-8");
        if (fptr == NULL) return file_path;

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

        setlocale(LC_ALL, ".65001");
        fptr = fopen(file_path.utf8().get_data(), "rb");
        if (fptr == NULL) return 1;

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
