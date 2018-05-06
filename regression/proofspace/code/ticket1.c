#include <pthread.h>

int in_critical;
int s;
int t;

pthread_mutex_t lock;

void* thread(void *arg) {
    int m;
    __VERIFIER_atomic_begin();
    m = t++;
    __VERIFIER_atomic_end();
    assume (s == m);
    in_critical = 1;
    assert(in_critical == 1);
    in_critical = 0;
    s++;
    return NULL;
}


void main() {
    pthread_t th;

    s = t = 0;

    int num = __VERIFIER_nondet();
    __VERIFIER_assume(num > 0);

    for (int i = 0; i < num; ++i){
      pthread_create(&th, NULL, thread, NULL);
    }
}
