alias dcl1="docker compose --env-file common.env --file l1.yml "
alias dcl2="docker compose --env-file l2.env --file l2.yml"
alias curlw="curl --request POST --header 'Content-Type: application/json' http://127.0.0.1:8545"
alias curlPostOPNode="curl --request POST --header 'Content-Type: application/json' http://node1:9545 --data"
alias curlPost="curl --request POST --header 'Content-Type: application/json'"
alias grep="grep --color -a"
alias ccl="curl -X 'GET' -H 'accept: application/json'"
alias dockerRun="docker run --pull always --rm -it"

