CURRENT_UID=$(id -u):$(id -g) docker-compose -f docker-compose.dev.yml up --build --detach
