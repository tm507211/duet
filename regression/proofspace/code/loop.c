//#include <pthread.h>

/* void* thr(void* arg) {
  return NULL;
}

void main() {
  pthread_t t;
  pthread_create(&t, NULL, thr, NULL);
}
*/

void main() {
  int a = 0;
  int i = 0;
  int num = 40;

  while (i < num){
    a = a + 1;
    if (a == 20) {
      a = 4;
    }
    i = i + 1;
  }
  assert (a <= 20);
}
