// Small bridge between the Doom engine (C) and the Swift menu bar app.
#ifndef MENUDOOM_H
#define MENUDOOM_H

#include <stdint.h>

#ifdef __cplusplus
extern "C" {
#endif

// Doom engine entry points (from doomgeneric).
void doomgeneric_Create(int argc, char **argv);
void doomgeneric_Tick(void);

// Frame access. Pixels are 0x00RRGGBB, row-major, mdg_width() * mdg_height().
const uint32_t *mdg_pixels(void);
int mdg_width(void);
int mdg_height(void);

// Returns 1 if Doom drew a new frame since the last call, then clears the flag.
int mdg_take_frame(void);

// Queue a key event for Doom. `key` is a Doom key code (see doomkeys.h).
void mdg_push_key(int pressed, unsigned char key);

// Doom key codes Swift needs.
enum {
    MDG_KEY_RIGHT  = 0xae,
    MDG_KEY_LEFT   = 0xac,
    MDG_KEY_UP     = 0xad,
    MDG_KEY_DOWN   = 0xaf,
    MDG_KEY_USE    = 0xa2,
    MDG_KEY_FIRE   = 0xa3,
    MDG_KEY_ESCAPE = 27,
    MDG_KEY_ENTER  = 13,
    MDG_KEY_TAB    = 9,
    MDG_KEY_BACKSPACE = 0x7f,
    MDG_KEY_RSHIFT = 0x80 + 0x36,
    MDG_KEY_RALT   = 0x80 + 0x38,
    MDG_KEY_F1     = 0x80 + 0x3b,
    MDG_KEY_EQUALS = 0x3d,
    MDG_KEY_MINUS  = 0x2d,
    MDG_KEY_PAUSE  = 0xff
};

#ifdef __cplusplus
}
#endif

#endif
