P1 = 
```
curl -Uri http://localhost:8080/join -Method Post -Body '{"player_id": "1", "player_name": "Player1"}'
```
(expect failure since host has not joined)


R =
```
curl -Uri http://localhost:8080/join -Method Post -Body '{"referee_id": "referee007", "referee_secret": "superconfidential"}'
```


P1...8 = 
```
curl -Uri http://localhost:8080/join -Method Post -Body '{"player_id": "1", "player_name": "Player1"}'
curl -Uri http://localhost:8080/join -Method Post -Body '{"player_id": "2", "player_name": "Player2"}'
curl -Uri http://localhost:8080/join -Method Post -Body '{"player_id": "3", "player_name": "Player3"}'
curl -Uri http://localhost:8080/join -Method Post -Body '{"player_id": "4", "player_name": "Player4"}'
curl -Uri http://localhost:8080/join -Method Post -Body '{"player_id": "5", "player_name": "Player5"}'
curl -Uri http://localhost:8080/join -Method Post -Body '{"player_id": "6", "player_name": "Player6"}'
curl -Uri http://localhost:8080/join -Method Post -Body '{"player_id": "7", "player_name": "Player7"}'
curl -Uri http://localhost:8080/join -Method Post -Body '{"player_id": "8", "player_name": "Player8"}'
```
(expect response after 8th client has sent join request)

P1...P8 : 
```
curl -Uri http://localhost:8080/offend -Method Post -Body '{"value": "1",}'
curl -Uri http://localhost:8080/defend -Method Post -Body '{"value": "2,3,4",}'
```
(expect response when opponent has also sent their move request)