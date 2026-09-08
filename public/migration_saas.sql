-- ==============================================================================
-- PRUMO ERP — MIGRAÇÃO SAAS + EMBAIXADORES + TRAVA TEMPORAL
-- Execute este script no SQL Editor do Supabase para aplicar a migração
-- ==============================================================================

-- 1. ADICIONAR COLUNAS SAAS NA TABELA STORES
ALTER TABLE public.stores 
  ADD COLUMN IF NOT EXISTS acesso_ativo BOOLEAN DEFAULT true,
  ADD COLUMN IF NOT EXISTS data_fim_teste TIMESTAMPTZ DEFAULT (NOW() + INTERVAL '7 days'),
  ADD COLUMN IF NOT EXISTS dias_teste_padrao INT DEFAULT 7,
  ADD COLUMN IF NOT EXISTS mensalidade NUMERIC(12,2) DEFAULT 2500.00,
  ADD COLUMN IF NOT EXISTS idioma VARCHAR(2) DEFAULT 'PT',
  ADD COLUMN IF NOT EXISTS embaixador_id VARCHAR(50) NULL;

-- 2. CRIAR TABELA DE EMBAIXADORES
CREATE TABLE IF NOT EXISTS public.embaixadores (
  id VARCHAR(50) PRIMARY KEY,
  nome VARCHAR(255) NOT NULL,
  email VARCHAR(255) UNIQUE NOT NULL,
  senha VARCHAR(255) NOT NULL,
  telefone VARCHAR(50),
  pais VARCHAR(100),
  cidade VARCHAR(100),
  chave_pagamento VARCHAR(255),
  created_at TIMESTAMPTZ DEFAULT NOW()
);

-- 3. ATUALIZAR ROLE DO PROFILE (Permitir SUPERADMIN e EMBAIXADOR)
ALTER TABLE public.profiles 
  DROP CONSTRAINT IF EXISTS profiles_role_check;
ALTER TABLE public.profiles
  ADD CONSTRAINT profiles_role_check CHECK (role IN ('ADMIN', 'GERENTE', 'CASHIER', 'ESTOQUISTA', 'SUPERADMIN', 'EMBAIXADOR'));

-- 4. VIEW PRA MONITOR SAAS
CREATE OR REPLACE VIEW public.view_monitor_stores AS
SELECT 
  s.*, 
  e.nome as nome_embaixador,
  GREATEST(0, CEIL(EXTRACT(EPOCH FROM (s.data_fim_teste - NOW())) / 86400))::INT as dias_restantes,
  CASE 
    WHEN s.acesso_ativo = false THEN 'Suspenso'
    WHEN s.data_fim_teste > NOW() THEN 'Teste'
    ELSE 'Ativo'
  END as status
FROM public.stores s
LEFT JOIN public.embaixadores e ON s.embaixador_id = e.id;

-- 5. ATUALIZAR LOJAS ANTIGAS PARA O PERÍODO DE TESTE
UPDATE public.stores 
SET data_fim_teste = NOW() + INTERVAL '7 days' 
WHERE data_fim_teste IS NULL;

-- 6. CRIAR ÍNDICES DE PERFORMANCE PARA AS NOVAS CONSULTAS
CREATE INDEX IF NOT EXISTS idx_stores_embaixador ON public.stores(embaixador_id);
CREATE INDEX IF NOT EXISTS idx_stores_acesso_ativo ON public.stores(acesso_ativo);
CREATE INDEX IF NOT EXISTS idx_stores_data_fim_teste ON public.stores(data_fim_teste);
