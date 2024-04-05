FROM mcr.microsoft.com/dotnet/sdk:8.0

ADD ["entrypoint.ps1", "/data/"]

RUN chmod +x /data/entrypoint.ps1

ENTRYPOINT ["/data/entrypoint.ps1"]