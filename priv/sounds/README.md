add a header to a mp3 file to send it through audio stream


```bash

# 1. Read the file as binary
file_binary = File.read!("/path/to/mp3/file/chunk0.mp3")

file_binary_size = byte_size(file_binary)
data_type = 2 # it means that it is a ringtone

# MS is a tag that is used to define where package is started

# 2. Combine header and file data
new_binary_data = <<"M", "S", file_binary_size::32, data_type::8>> <> file_binary

# 4. Save to a new file (optional)
File.write!("/path/to/mp3/file/chunk0.mp3", new_binary_data)
```