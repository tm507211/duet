#include <pthread.h>
#define LOOPS 2

int x;
int y;

void* thr1(void* arg) {
  int i = 0;
  while (i < LOOPS) {
    x = x + 1;
    i = i + 1;
  }
  y = y + 1;
  return NULL;
}

void* thr2(void* arg) {
  int i = 0;
  while (i < LOOPS) {
    x = x + 2;
    i = i + 1;
  }
  y = y + 1;
  return NULL;
}

void main() {

  x = 0;
  y = 0;
  
  pthread_t t1, t2;  
  pthread_create(&t1, NULL, thr1, NULL);
  pthread_create(&t2, NULL, thr2, NULL);

  while(y < 2);
  assert (x >= 3*LOOPS);
}
