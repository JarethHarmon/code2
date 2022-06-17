#include <Godot.hpp>
#include <Node.hpp>
#include <File.hpp>
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
        register_method("get_komi_hash", &Gob::get_komi_hash);
    }

    void _init()
    {
    }

    String get_komi_hash(String file_path)
    {
        FILE* fptr;
        char* buffer;
        long filelen;

        setlocale(LC_ALL, ".65001");
        fptr = fopen(file_path.utf8().get_data(), "rb");
        //fptr = fopen(file_path.utf8().get_data(), "rb, ccs=UTF-8");
        if (fptr != NULL) {
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
        else {
            // prints a ton of unicode 'errors' in debug mode, which slows down importing a lot
            // however, release builds do not print and so it runs at full speed 
            File *test = File::_new();
            test->open(file_path, 1); // 1 is read, not sure how to access the constant from c++
            String s = test->get_as_text();

            uint64_t kh = komihash(s.utf8().get_data(), test->get_len(), 0);
            return String(std::to_string(kh).c_str());
        }
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
