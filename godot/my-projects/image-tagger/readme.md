# Description

# GDNative
### Komihash
I chose to use (for now anyways) [komihash](https://github.com/avaneev/komihash/) as the hashing algorithm used for checking image uniqueness for the following reasons:
1. While inherently not as unique as SHA256 I should not have to worry about collisions (I will switch to SHA256 if this turns out to be false)
2. Komihash is ~2x faster for average-sized images, ~40% faster for large images, and ~20% faster for tiny images.
3. Komihash is 64bits as opposed to SHA256's 256 bits. This means that it takes significantly less space on disk and in memory.
