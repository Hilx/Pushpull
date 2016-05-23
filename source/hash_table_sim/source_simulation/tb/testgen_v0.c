#include <stdio.h>

int main(void){
  FILE *f;
  f = fopen("test_v0.txt","w");
  if(f == NULL){
    printf("Error opening file!\n");

  }else{
    // data gen
    int i,j;
    for(i = 0; i <14; i++){
      fprintf(f,"(%d, x\"00000000\",'0'),\n", i);
      j = i;
    }
    j++;
    fprintf(f,"(%d, x\"00000001\",'0'),\n", j);
    j++;
    fprintf(f,"(%d, x\"00000000\",'0'),\n", j);
    j++;
    fprintf(f,"(%d, x\"11111111\",'1') -- INVALID INPUT, only signaling the tb to finish", j);
    fclose(f);
  }

  return 0;
}
