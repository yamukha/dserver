http server for "fake mining" implemented in D language

Notes: 
1. Checked under Windows 7
2. Doing "fake mining" every second
3. Need to run redis-server to save "mined blocks"
4. Start "fake mining" after request to /transaction endpoint i.e.
curl -X POST -H "Content-Type: application/json" http://127.0.0.1:2826/transaction --data-raw '{"outputs":[{"key":"0xee0edfbe581fa81481e858f75fda3414cd3a655ff17ec987af775e666412bf1f","amount":4000000},{"key":"0xf4012c71c9be512613c4820a3f6b1e55f8515a441913cf9cb06ccc3076ccbebd","amount":96000000}],"inputs":[{"hash":"0xc2c5be0cb790c8d85b9096c409dd439aebaa9af6df2e476d23f8d6f624e87f95","sig":"0x0ec47ca9f8d0101a8c3cabf6ba1fa73aa123294dcf0f5578addc5f01463f7dfc1bd3719636a77f3e4f95b07f1b77a2a58df046c6aa66e4bec91d908a66c3f608","index":0},{"hash":"0xc2c5be0cb790c8d85b9096c409dd439aebaa9af6df2e476d23f8d6f624e87f95","sig":"0x096a7ff44ee2a1d88674b2ba5583a00fd47ccb80ebc2761b40361e4319bc7da9080304ea87d46c5401d6b92f4304fb176f1f5e0dce9872024297659be7a83774","index":1}]}'
5. Prints "mined blocks"  request to /blocks endpoint i.e.
curl  127.0.0.1:2826/blocks