/* MurdlBridge: C interface over the MurdlCore engine.
 * Link against MurdlBridge.dll / libMurdlBridge.dylib. Handles are opaque; free them
 * with murdl_match_free. Strings returned by this library are freed with murdl_string_free.
 */
#ifndef MURDL_H
#define MURDL_H

#include <stdint.h>

#ifdef __cplusplus
extern "C" {
#endif

typedef void *murdl_match;

int32_t murdl_version(void);

murdl_match murdl_match_new(int32_t board_count);                      /* 2, 4, 8, or 16; NULL otherwise */
murdl_match murdl_match_new_with_answers(const char *comma_separated); /* fixed answers, e.g. "crane,slate" */
void murdl_match_free(murdl_match match);

void murdl_match_set_typing(murdl_match match, const char *letters);
int32_t murdl_match_validate(murdl_match match, const char *word);     /* 0 ok, 1 over, 2 length, 3 not a word */
int32_t murdl_match_play(murdl_match match, const char *word);         /* boards solved, or -1 if refused */
void murdl_match_lose_unfinished(murdl_match match);                   /* Sprint time-out */
char *murdl_match_state_json(murdl_match match);                       /* MatchSnapshot as JSON */

char *murdl_score(const char *guess, const char *answer);              /* five chars: A, P, or C */
int32_t murdl_dictionary_contains(const char *word);

void murdl_string_free(char *string);

#ifdef __cplusplus
}
#endif
#endif
