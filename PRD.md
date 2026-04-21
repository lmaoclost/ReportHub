# ReportHub — PRD
**Plataforma de Relatórios Assíncronos** · Build to Learn · v1.0

---

## Sumário

- [Visão Geral](#visão-geral)
- [Persona](#persona)
- [Arquitetura](#arquitetura)
- [Tech Stack](#tech-stack)
- [Serviços AWS Simulados](#serviços-aws-simulados)
- [User Stories](#user-stories)
- [Milestones e Tasks](#milestones-e-tasks)
- [Requisitos Não Funcionais](#requisitos-não-funcionais)
- [Fora do Escopo](#fora-do-escopo)
- [Definition of Done](#definition-of-done)
- [Critério de Sucesso](#critério-de-sucesso)

---

## Visão Geral

O ReportHub simula uma plataforma SaaS de geração de relatórios assíncronos. Usuários autenticados configuram, solicitam e acompanham relatórios de dados. O processamento acontece em background via Celery, o arquivo gerado vai para o S3, e o usuário recebe notificação por e-mail via SES e feedback em tempo real via WebSocket.

O objetivo não é entregar um produto comercial — é percorrer o stack Django + React que o mercado LATAM exige, com cada ferramenta justificada pelo problema que resolve.

---

## Persona

**Ana — Analista de Dados**

- Precisa gerar relatórios semanais de vendas por região
- Quer solicitar o relatório e continuar trabalhando enquanto processa
- Precisa receber o arquivo por e-mail quando ficar pronto
- Quer ver o histórico de relatórios já gerados
- Pode agendar relatórios recorrentes (ex: todo domingo às 8h)

---

## Arquitetura

```
React (TypeScript + Zustand)
  │  REST (DRF)          WebSocket (Django Channels)
  ▼                      ▼
Django ──────────────── Redis (channel layer + Celery broker)
  │                       │
PostgreSQL            Celery Worker
                          │
                      LocalStack
                      (S3 · SES · Secrets Manager)
```

### Fluxo principal — geração de relatório

1. Usuário faz `POST /api/reports/` com parâmetros
2. Django cria `ReportTask` com status `PENDING` e retorna `202 Accepted`
3. Frontend abre WebSocket e exibe barra de progresso
4. Celery pega a tarefa, processa dados, atualiza status para `PROCESSING`
5. Arquivo gerado é salvo no S3; status atualizado para `DONE`
6. Django Channels envia evento de progresso (100%) via WebSocket
7. Celery dispara e-mail SES com presigned URL do S3 (expiração: 24h)

---

## Tech Stack

| Camada | Tecnologia | Versão alvo |
|--------|-----------|-------------|
| Backend | Python | 3.12 |
| Backend | Django | 5.1+ |
| Backend | Django REST Framework | 3.15+ |
| Backend | Django Channels | 4.x |
| Backend | Celery | 5.x |
| Backend | boto3 | latest |
| Banco | PostgreSQL | 16+ |
| Broker / Cache | Redis | 7+ |
| Frontend | React | 18+ |
| Frontend | TypeScript | 5.x |
| Frontend | Vite | 5.x |
| Frontend | Zustand | 4.x |
| Frontend | Tailwind CSS | 3.x |
| Testes BE | pytest + pytest-django | latest |
| Testes BE | Moto | 5.x |
| Testes FE | Jest + React Testing Library | latest |
| Infra | Docker + Compose | — |
| Infra | LocalStack | latest |
| Infra | GitHub Actions | — |

---

## Serviços AWS Simulados

> Todos os serviços rodam via **LocalStack** no dev local e via **Moto** nos testes automatizados. Nenhuma conta AWS real é necessária.

| Serviço | Emulação | Uso no projeto |
|---------|----------|---------------|
| S3 | LocalStack + Moto | Armazena os CSVs gerados. Presigned URLs com expiração de 24h para download. |
| SES | LocalStack + Moto | Envia e-mail de notificação com template HTML quando o relatório fica pronto. |
| Secrets Manager | LocalStack + Moto | Armazena credenciais sensíveis lidas pelo Django na inicialização via boto3. |

---

## User Stories

### Autenticação

| Story | Prioridade | Critério de aceite |
|-------|-----------|-------------------|
| Como usuária, quero me cadastrar com e-mail e senha | Alta | Conta criada, e-mail de boas-vindas enviado via SES, JWT retornado |
| Como usuária, quero fazer login e receber um token JWT | Alta | Access token (15min) e refresh token (7 dias) retornados |
| Como usuária, quero renovar meu token sem fazer login novamente | Alta | `POST /api/auth/refresh/` com refresh token válido retorna novo access token |
| Como usuária, quero fazer logout invalidando o token | Média | Refresh token na blocklist; chamadas subsequentes retornam 401 |
| Como usuária, quero fazer login com Google (OAuth2) | Baixa | Flow OAuth2 completo; conta criada automaticamente se não existir |

### Relatórios

| Story | Prioridade | Critério de aceite |
|-------|-----------|-------------------|
| Como usuária, quero solicitar a geração de um relatório com parâmetros | Alta | Retorna 202 com ID da tarefa; status `PENDING` visível imediatamente |
| Como usuária, quero ver o progresso em tempo real | Alta | Barra de progresso atualiza via WebSocket sem recarregar a página |
| Como usuária, quero baixar o relatório quando estiver pronto | Alta | Presigned URL disponível por 24h; download funciona sem autenticação AWS |
| Como usuária, quero receber um e-mail com o link de download | Alta | E-mail SES enviado com template HTML e link correto ao mudar para `DONE` |
| Como usuária, quero ver o histórico dos meus relatórios | Alta | Lista paginada com status, data, tipo e link de download |
| Como usuária, quero cancelar um relatório `PENDING` | Média | Tarefa revogada no Celery; status atualizado para `CANCELLED` |
| Como usuária, quero agendar um relatório recorrente | Média | Celery Beat cria a tarefa no horário configurado automaticamente |
| Como usuária, quero filtrar o histórico por status e data | Baixa | Filtros via query params; resultado paginado |

---

## Milestones e Tasks

> **Legenda de status:** `[ ]` a fazer · `[x]` concluído · `[~]` em progresso

---

### Milestone 1 — Base
**Objetivo:** ambiente funcionando, modelo de dados definido, CRUD básico sem async.

#### Infraestrutura
- [ ] Criar repositório com estrutura de pastas (`backend/`, `frontend/`, `docker/`)
- [ ] `docker-compose.yml` com Django, PostgreSQL e Redis
- [ ] Health checks configurados para postgres e redis
- [ ] `.env.example` com todas as variáveis necessárias documentadas
- [ ] `Makefile` com atalhos: `make up`, `make down`, `make test`, `make lint`

#### Backend — Models
- [ ] Custom `User` model (email como username)
- [ ] Model `Report` (tipo, parâmetros JSON, dono, created_at)
- [ ] Model `ReportTask` (report FK, status, progresso %, mensagem de erro, started/finished_at)
- [ ] Migrations geradas e aplicadas no container
- [ ] Django Admin configurado para Report e ReportTask

#### Backend — API REST
- [ ] `POST /api/auth/register/` — cadastro com e-mail e senha
- [ ] `POST /api/auth/login/` — retorna access + refresh token
- [ ] `POST /api/auth/refresh/` — renova access token
- [ ] `POST /api/auth/logout/` — invalida refresh token
- [ ] `GET /api/reports/` — lista paginada dos relatórios do usuário autenticado
- [ ] `POST /api/reports/` — cria relatório (síncrono por ora, sem Celery)
- [ ] `GET /api/reports/:id/` — detalhe do relatório
- [ ] Permissões: usuário só acessa os próprios relatórios

#### Testes — Fase 1
- [ ] Testes dos models (factories com `factory_boy`)
- [ ] Testes dos endpoints de auth (register, login, refresh, logout)
- [ ] Testes do CRUD de relatórios (criação, listagem, permissões)

---

### Milestone 2 — Processamento Assíncrono
**Objetivo:** geração real de relatório via Celery com progresso armazenado no banco.

#### Celery
- [ ] Celery worker e Celery beat no `docker-compose.yml`
- [ ] Flower no Compose (porta 5555) para monitoramento visual
- [ ] Configuração de filas: `reports` (alta prioridade) e `default`
- [ ] Task `generate_report`: lê parâmetros, gera CSV com dados simulados, salva localmente
- [ ] Task atualiza `ReportTask.progress` a cada etapa (0 → 25 → 50 → 75 → 100)
- [ ] Retry automático em falha: máx. 3 tentativas com backoff exponencial
- [ ] `POST /api/reports/` passa a retornar `202 Accepted` e enfileirar a task

#### API de status
- [ ] `GET /api/reports/:id/status/` retorna status atual e progresso
- [ ] `DELETE /api/reports/:id/` cancela tarefa `PENDING` (revoga no Celery)

#### Testes — Fase 2
- [ ] Testes de tasks com `CELERY_TASK_ALWAYS_EAGER = True`
- [ ] Teste de retry: simular falha e verificar comportamento
- [ ] Teste do endpoint de cancelamento

---

### Milestone 3 — Integração AWS Local
**Objetivo:** S3 para storage, SES para e-mail, Secrets Manager para credenciais.

#### LocalStack
- [ ] LocalStack no `docker-compose.yml` (porta 4566)
- [ ] Script de inicialização (`localstack/init.sh`): cria bucket S3, registra identidade SES, cria secrets
- [ ] `awscli-local` configurado para uso nos scripts

#### S3
- [ ] `S3Client` wrapper em `integrations/aws/s3.py`
- [ ] Task salva CSV no S3 (`users/{user_id}/reports/{report_id}.csv`) ao invés do disco
- [ ] Presigned URL gerada com expiração de 24h
- [ ] `GET /api/reports/:id/` retorna `download_url` quando status é `DONE`

#### SES
- [ ] `SESClient` wrapper em `integrations/aws/ses.py`
- [ ] Template HTML de notificação criado no LocalStack
- [ ] Task dispara e-mail SES ao mudar status para `DONE`
- [ ] E-mail contém: nome do relatório, data de geração e botão de download

#### Secrets Manager
- [ ] `SecretsClient` wrapper em `integrations/aws/secrets.py`
- [ ] Django settings lê credenciais sensíveis do Secrets Manager na inicialização
- [ ] Fallback para `.env` quando LocalStack não está disponível (ambiente de testes)

#### Testes — Fase 3
- [ ] `@mock_aws` cobrindo toda a task `generate_report` (S3 + SES)
- [ ] Teste de `S3Client.upload` e `S3Client.generate_presigned_url`
- [ ] Teste de `SESClient.send_notification`
- [ ] Teste de `SecretsClient.get_secret`

---

### Milestone 4 — Real-time com WebSocket
**Objetivo:** frontend React conectado com progresso via WebSocket.

#### Django Channels
- [ ] Django Channels instalado e ASGI configurado
- [ ] Redis como channel layer configurado
- [ ] Consumer `ReportProgressConsumer` (grupo por `report_{id}`)
- [ ] Task publica progresso no canal a cada atualização de status
- [ ] Autenticação JWT no handshake WebSocket

#### Frontend — Setup
- [ ] Projeto React + TypeScript + Vite criado em `frontend/`
- [ ] Tailwind CSS configurado
- [ ] Zustand instalado e store de auth criada (`useAuthStore`)
- [ ] Axios client com interceptor para JWT (attach + refresh automático)
- [ ] Páginas: Login, Register, Dashboard, ReportDetail

#### Frontend — Funcionalidades
- [ ] Listagem de relatórios com polling de status (fallback sem WS)
- [ ] Hook `useWebSocket(reportId)` — conecta ao canal e ouve progresso
- [ ] Zustand store `useReportStore` — lista, status individual, ações
- [ ] Formulário de criação de relatório com parâmetros (datas, tipo)
- [ ] Barra de progresso animada no `ReportDetail`
- [ ] Botão de download aparece quando status é `DONE`
- [ ] Toast de notificação ao receber evento `DONE` via WebSocket

#### Testes — Fase 4
- [ ] Teste do consumer WebSocket com `WebsocketCommunicator`
- [ ] Testes de componentes React com React Testing Library
- [ ] Teste do hook `useWebSocket` com mock de WebSocket

---

### Milestone 5 — Profissionalização
**Objetivo:** agendamento, CI/CD, cobertura de testes e polish geral.

#### Agendamento
- [ ] Model `ReportSchedule` (relatório recorrente, expressão crontab, ativo/inativo)
- [ ] `POST /api/schedules/` — cria agendamento
- [ ] `DELETE /api/schedules/:id/` — desativa agendamento
- [ ] Task periódica no `django-celery-beat` registrada via migration

#### Segurança e Performance
- [ ] Rate limiting no endpoint de login (máx. 10 tentativas/minuto por IP)
- [ ] CORS configurado para aceitar apenas a origem do frontend
- [ ] Índices de banco revisados (ReportTask.status + ReportTask.report_id)
- [ ] `select_related` e `prefetch_related` nas queries de listagem

#### CI/CD
- [ ] GitHub Actions: lint (ruff + ESLint) em todo push
- [ ] GitHub Actions: pytest com coverage report em todo PR
- [ ] Badge de coverage no README
- [ ] Secrets do repositório configurados para o pipeline

#### OAuth2
- [ ] `social-auth-app-django` instalado e configurado
- [ ] Login com Google funcionando em desenvolvimento
- [ ] Frontend com botão "Entrar com Google"

#### Observabilidade
- [ ] Logs estruturados em JSON no Django
- [ ] Sentry configurado (free tier) para captura de erros em produção simulada

---

## Requisitos Não Funcionais

| # | Requisito | Critério |
|---|-----------|---------|
| RNF-01 | Segurança | Nenhuma credencial hardcoded; tudo via Secrets Manager ou `.env` |
| RNF-02 | Testes | Cobertura mínima de 70% no backend |
| RNF-03 | Lint | ruff sem warnings no backend; ESLint sem warnings no frontend |
| RNF-04 | Commits | Mensagens semânticas: `feat`, `fix`, `chore`, `test`, `docs` |
| RNF-05 | Logs | Logs estruturados (JSON) com nível configurável por ambiente |
| RNF-06 | CORS | Aceita apenas a origem do frontend configurada via env |

---

## Fora do Escopo

- Deploy em AWS real (EC2, ECS, Lambda) — LocalStack cobre o aprendizado necessário
- Multitenancy (organizações, times) — complexidade desnecessária para o objetivo
- Relatórios em PDF com gráficos — CSV exercita o fluxo completo
- App mobile — React web é suficiente
- Billing e planos pagos — sem fins comerciais
- Internacionalização (i18n)

---

## Definition of Done

Uma feature está concluída quando:

- [ ] Código passa no lint sem warnings
- [ ] Testes relevantes escritos e passando
- [ ] Funcionalidade verificável manualmente (curl / browser)
- [ ] Código commitado com mensagem semântica
- [ ] README de progresso atualizado com o que foi aprendido

---

## Critério de Sucesso

O projeto é um sucesso se, ao final, você conseguir:

1. Explicar o fluxo completo de uma requisição assíncrona (HTTP → Celery → WebSocket → e-mail) sem consultar documentação
2. Escrever um teste unitário de uma task Celery que acesse S3 com Moto em menos de 10 minutos
3. Montar um `docker-compose.yml` do zero com todos os serviços em menos de 30 minutos
4. Responder em entrevista o que é um channel layer e por que Redis serve tanto para Celery quanto para WebSocket
5. Diferenciar LocalStack (emulação de ambiente) de Moto (mock em testes) quando perguntado
