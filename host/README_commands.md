R : Start hosting
```
dart run
```

P1...P8 : Print Game Info
```
curl -Uri http://localhost:8080/ -Method Get
```


P1...8 : Join Championship with name and password
```
curl -Uri http://localhost:8080/join -Method Post -Body '{"player_password":"Eliud", "player_name": "Eliud"}'
curl -Uri http://localhost:8080/join -Method Post -Body '{"player_password":"Mo", "player_name": "Mo"}'
curl -Uri http://localhost:8080/join -Method Post -Body '{"player_password":"Mary", "player_name": "Mary"}'
curl -Uri http://localhost:8080/join -Method Post -Body '{"player_password":"Usain", "player_name": "Usain"}'
curl -Uri http://localhost:8080/join -Method Post -Body '{"player_password":"Paula", "player_name": "Paula"}'
curl -Uri http://localhost:8080/join -Method Post -Body '{"player_password":"Galen", "player_name": "Galen"}'
curl -Uri http://localhost:8080/join -Method Post -Body '{"player_password":"Shalane", "player_name": "Shalane"}'
curl -Uri http://localhost:8080/join -Method Post -Body '{"player_password":"Haile", "player_name": "Haile"}'
```
(expect response after 8th client has sent join request)


P1...P8 : Register game move
```
$headers = @{ "Authorization" = "Bearer token" }
curl -Uri http://localhost:8080/move -Method Post -Headers $headers -Body '{"offence": 1,}'
curl -Uri http://localhost:8080/move -Method Post -Headers $headers -Body '{"defence": [2,3,4],}'
```
(expect response when opponent has also sent their move request)


P1...P8 : Query game instructions
```
$headers = @{ "Authorization" = "Bearer token" }
curl -Uri http://localhost:8080/game -Method Get -Headers $headers
```