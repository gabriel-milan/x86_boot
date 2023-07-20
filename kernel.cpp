// Defines the kernel entry point
extern "C" void main()
{
    // In text mode, the screen buffer is at B8000
    // We will write a multiple-character string to it
    char *video_memory = (char *)0xb8000;
    // Write a string to the screen
    char *str = "Hello, World!";
    for (int i = 0; i < 13; i++)
    {
        video_memory[i * 2] = str[i];
        video_memory[i * 2 + 1] = 0x07;
    }
    return;
}