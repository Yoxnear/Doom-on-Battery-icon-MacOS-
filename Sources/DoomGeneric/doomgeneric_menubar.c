// doomgeneric platform layer for the MenuDoom menu bar app.
// Drawing and input happen in Swift; this file just hands frames out
// and takes key events in.

#include <time.h>
#include <unistd.h>

#include "doomgeneric.h"
#include "include/menudoom.h"

#define KEYQUEUE_SIZE 64

static unsigned short key_queue[KEYQUEUE_SIZE];
static unsigned int key_write = 0;
static unsigned int key_read = 0;
static int frame_ready = 0;
static struct timespec start_time;

void mdg_push_key(int pressed, unsigned char key)
{
    unsigned int next = (key_write + 1) % KEYQUEUE_SIZE;
    if (next == key_read) {
        return; // queue full: drop the event
    }
    key_queue[key_write] = (unsigned short)(((pressed ? 1 : 0) << 8) | key);
    key_write = next;
}

const uint32_t *mdg_pixels(void) { return (const uint32_t *)DG_ScreenBuffer; }
int mdg_width(void) { return DOOMGENERIC_RESX; }
int mdg_height(void) { return DOOMGENERIC_RESY; }

int mdg_take_frame(void)
{
    int ready = frame_ready;
    frame_ready = 0;
    return ready;
}

void DG_Init(void)
{
    clock_gettime(CLOCK_MONOTONIC, &start_time);
}

void DG_DrawFrame(void)
{
    frame_ready = 1;
}

void DG_SleepMs(uint32_t ms)
{
    usleep(ms * 1000);
}

uint32_t DG_GetTicksMs(void)
{
    struct timespec now;
    clock_gettime(CLOCK_MONOTONIC, &now);
    return (uint32_t)((now.tv_sec - start_time.tv_sec) * 1000
                      + (now.tv_nsec - start_time.tv_nsec) / 1000000);
}

int DG_GetKey(int *pressed, unsigned char *key)
{
    if (key_read == key_write) {
        return 0;
    }
    unsigned short data = key_queue[key_read];
    key_read = (key_read + 1) % KEYQUEUE_SIZE;
    *pressed = data >> 8;
    *key = data & 0xff;
    return 1;
}

void DG_SetWindowTitle(const char *title)
{
    (void)title;
}
