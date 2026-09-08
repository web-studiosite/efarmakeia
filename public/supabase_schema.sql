-- ==============================================================================
-- PRUMO ERP — GESTOR DE FERRAGENS & MATERIAIS DE CONSTRUÇÃO (MULTI-LOJA)
-- ESQUEMA DE BANCO DE DADOS POSTGRESQL PARA SUPABASE
-- Execute este script no painel: Supabase Dashboard -> SQL Editor -> New Query -> Run
-- ==============================================================================

-- 1. Habilitar extensões
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";

-- 2. Tabela de Lojas / Filiais (Multi-Tenancy & SaaS)
CREATE TABLE IF NOT EXISTS public.stores (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    code VARCHAR(30) UNIQUE NOT NULL,
    name VARCHAR(255) NOT NULL,
    trade_name VARCHAR(255),
    cnpj_nif VARCHAR(50) NOT NULL,
    phone VARCHAR(50),
    email VARCHAR(100),
    address TEXT NOT NULL,
    city VARCHAR(100) NOT NULL,
    state VARCHAR(100) DEFAULT 'Maputo',
    currency VARCHAR(10) DEFAULT 'MT',
    is_headquarters BOOLEAN DEFAULT false,
    manager_name VARCHAR(150),
    receipt_header TEXT,
    receipt_footer TEXT,
    active BOOLEAN DEFAULT true,
    acesso_ativo BOOLEAN DEFAULT true,
    data_fim_teste TIMESTAMPTZ DEFAULT (NOW() + INTERVAL '7 days'),
    dias_teste_padrao INT DEFAULT 7,
    mensalidade NUMERIC(12,2) DEFAULT 2500.00,
    idioma VARCHAR(2) DEFAULT 'PT',
    embaixador_id VARCHAR(50) NULL,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- 2.1 Tabela de Parceiros Embaixadores
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

-- 3. Tabela de Perfis de Usuários & Papéis (Vinculada ao auth.users do Supabase)
CREATE TABLE IF NOT EXISTS public.profiles (
    id UUID PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
    full_name VARCHAR(255) NOT NULL,
    email VARCHAR(255) NOT NULL,
    phone VARCHAR(50),
    role VARCHAR(50) DEFAULT 'CASHIER' CHECK (role IN ('ADMIN', 'GERENTE', 'CASHIER', 'ESTOQUISTA', 'SUPERADMIN', 'EMBAIXADOR')),
    default_store_id UUID REFERENCES public.stores(id) ON DELETE SET NULL,
    avatar_url TEXT,
    active BOOLEAN DEFAULT true,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- 4. Tabela de Categorias e Produtos
CREATE TABLE IF NOT EXISTS public.products (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    store_id UUID REFERENCES public.stores(id) ON DELETE CASCADE,
    code VARCHAR(50) NOT NULL,
    barcode VARCHAR(100),
    name VARCHAR(255) NOT NULL,
    description TEXT,
    category VARCHAR(100) NOT NULL,
    base_unit VARCHAR(20) NOT NULL DEFAULT 'un',
    min_stock_alert NUMERIC(12, 3) DEFAULT 10,
    cost_price_base NUMERIC(12, 2) NOT NULL DEFAULT 0,
    sale_price_base NUMERIC(12, 2) NOT NULL DEFAULT 0,
    is_sold_by_weight BOOLEAN DEFAULT false,
    is_sold_by_length BOOLEAN DEFAULT false,
    active BOOLEAN DEFAULT true,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW(),
    UNIQUE(store_id, code)
);

-- 5. Estoque por Localização Físico (Loja, Armazém, Pátio de Agregados)
CREATE TABLE IF NOT EXISTS public.product_stock (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    product_id UUID REFERENCES public.products(id) ON DELETE CASCADE,
    store_id UUID REFERENCES public.stores(id) ON DELETE CASCADE,
    location VARCHAR(50) NOT NULL CHECK (location IN ('LOJA', 'ARMAZEM', 'PATIO')),
    quantity NUMERIC(12, 3) NOT NULL DEFAULT 0,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW(),
    UNIQUE(product_id, store_id, location)
);

-- 6. Embalagens e Conversões Fracionadas (Ex: Saco 50kg, Barra 12m, Metro, Unidade)
CREATE TABLE IF NOT EXISTS public.product_conversions (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    product_id UUID REFERENCES public.products(id) ON DELETE CASCADE,
    packaging_name VARCHAR(100) NOT NULL,
    multiplier NUMERIC(10, 3) NOT NULL DEFAULT 1,
    sale_price NUMERIC(12, 2) NOT NULL,
    barcode VARCHAR(100),
    active BOOLEAN DEFAULT true,
    created_at TIMESTAMPTZ DEFAULT NOW()
);

-- 7. Clientes & Contas Correntes de Fiado
CREATE TABLE IF NOT EXISTS public.customers (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    store_id UUID REFERENCES public.stores(id) ON DELETE SET NULL,
    name VARCHAR(255) NOT NULL,
    nuit VARCHAR(50),
    phone VARCHAR(50),
    address TEXT,
    credit_limit NUMERIC(12, 2) DEFAULT 0,
    current_debt NUMERIC(12, 2) DEFAULT 0,
    active BOOLEAN DEFAULT true,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- 8. Fornecedores de Materiais
CREATE TABLE IF NOT EXISTS public.suppliers (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    name VARCHAR(255) NOT NULL,
    trade_name VARCHAR(255),
    nuit VARCHAR(50),
    phone VARCHAR(50),
    email VARCHAR(100),
    city VARCHAR(100),
    active BOOLEAN DEFAULT true,
    created_at TIMESTAMPTZ DEFAULT NOW()
);

-- 9. Sessões de Turno e Caixa (Fechamento Cego)
CREATE TABLE IF NOT EXISTS public.cash_sessions (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    store_id UUID REFERENCES public.stores(id) ON DELETE CASCADE,
    operator_id UUID REFERENCES public.profiles(id) ON DELETE SET NULL,
    operator_name VARCHAR(150) NOT NULL,
    opened_at TIMESTAMPTZ DEFAULT NOW(),
    closed_at TIMESTAMPTZ,
    initial_float NUMERIC(12, 2) NOT NULL DEFAULT 0,
    total_sales_cash NUMERIC(12, 2) DEFAULT 0,
    total_sales_card NUMERIC(12, 2) DEFAULT 0,
    total_sales_mpesa NUMERIC(12, 2) DEFAULT 0,
    total_sales_credit NUMERIC(12, 2) DEFAULT 0,
    total_sangrias NUMERIC(12, 2) DEFAULT 0,
    expected_cash NUMERIC(12, 2) DEFAULT 0,
    counted_cash NUMERIC(12, 2),
    difference NUMERIC(12, 2),
    is_closed BOOLEAN DEFAULT false,
    closing_notes TEXT,
    created_at TIMESTAMPTZ DEFAULT NOW()
);

-- 10. Movimentos de Caixa (Sangrias, Suprimentos)
CREATE TABLE IF NOT EXISTS public.cash_movements (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    session_id UUID REFERENCES public.cash_sessions(id) ON DELETE CASCADE,
    store_id UUID REFERENCES public.stores(id) ON DELETE CASCADE,
    type VARCHAR(50) NOT NULL,
    amount NUMERIC(12, 2) NOT NULL,
    description TEXT NOT NULL,
    operator_name VARCHAR(150) NOT NULL,
    destination VARCHAR(100),
    created_at TIMESTAMPTZ DEFAULT NOW()
);

-- 11. Vendas e Emissão de Comprovativos
CREATE TABLE IF NOT EXISTS public.sales (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    store_id UUID REFERENCES public.stores(id) ON DELETE CASCADE,
    sale_number VARCHAR(50) NOT NULL,
    cashier_name VARCHAR(150) NOT NULL,
    customer_id UUID REFERENCES public.customers(id) ON DELETE SET NULL,
    customer_name VARCHAR(255),
    subtotal NUMERIC(12, 2) NOT NULL,
    discount NUMERIC(12, 2) DEFAULT 0,
    total NUMERIC(12, 2) NOT NULL,
    payment_method VARCHAR(50) NOT NULL,
    location VARCHAR(50) DEFAULT 'LOJA',
    cash_tendered NUMERIC(12, 2),
    change_given NUMERIC(12, 2),
    is_canceled BOOLEAN DEFAULT false,
    created_at TIMESTAMPTZ DEFAULT NOW()
);

-- 12. Itens da Venda
CREATE TABLE IF NOT EXISTS public.sale_items (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    sale_id UUID REFERENCES public.sales(id) ON DELETE CASCADE,
    product_id UUID REFERENCES public.products(id) ON DELETE SET NULL,
    product_name VARCHAR(255) NOT NULL,
    quantity NUMERIC(10, 3) NOT NULL,
    unit_price NUMERIC(12, 2) NOT NULL,
    selected_unit VARCHAR(50) NOT NULL,
    total NUMERIC(12, 2) NOT NULL,
    created_at TIMESTAMPTZ DEFAULT NOW()
);

-- 13. Transferências Entre Lojas / Filiais (Inter-Store Transfers)
CREATE TABLE IF NOT EXISTS public.store_transfers (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    transfer_number VARCHAR(50) NOT NULL,
    from_store_id UUID REFERENCES public.stores(id) ON DELETE RESTRICT,
    to_store_id UUID REFERENCES public.stores(id) ON DELETE RESTRICT,
    from_location VARCHAR(50) NOT NULL,
    to_location VARCHAR(50) NOT NULL,
    product_id UUID REFERENCES public.products(id) ON DELETE RESTRICT,
    product_code VARCHAR(50) NOT NULL,
    product_name VARCHAR(255) NOT NULL,
    quantity NUMERIC(12, 3) NOT NULL,
    unit VARCHAR(20) NOT NULL,
    status VARCHAR(50) DEFAULT 'PENDENTE' CHECK (status IN ('PENDENTE', 'EM_TRANSITO', 'CONCLUIDO', 'CANCELADO')),
    vehicle_plate VARCHAR(30),
    driver_name VARCHAR(100),
    dispatch_notes TEXT,
    dispatched_by VARCHAR(150) NOT NULL,
    dispatched_at TIMESTAMPTZ DEFAULT NOW(),
    received_by VARCHAR(150),
    received_at TIMESTAMPTZ
);

-- 14. Registro de Perdas & Avarias
CREATE TABLE IF NOT EXISTS public.losses (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    store_id UUID REFERENCES public.stores(id) ON DELETE CASCADE,
    product_id UUID REFERENCES public.products(id) ON DELETE SET NULL,
    product_name VARCHAR(255) NOT NULL,
    quantity NUMERIC(12, 3) NOT NULL,
    location VARCHAR(50) NOT NULL,
    reason VARCHAR(100) NOT NULL,
    total_cost NUMERIC(12, 2) NOT NULL,
    operator_name VARCHAR(150) NOT NULL,
    notes TEXT,
    created_at TIMESTAMPTZ DEFAULT NOW()
);

-- 15. Auditoria Centralizada
CREATE TABLE IF NOT EXISTS public.audit_logs (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    store_id UUID REFERENCES public.stores(id) ON DELETE SET NULL,
    operator_name VARCHAR(150) NOT NULL,
    action VARCHAR(100) NOT NULL,
    entity VARCHAR(100) NOT NULL,
    details TEXT NOT NULL,
    created_at TIMESTAMPTZ DEFAULT NOW()
);

-- SEED INICIAL: Lojas Matriz e Filiais de Exemplo
INSERT INTO public.stores (code, name, trade_name, cnpj_nif, phone, email, address, city, currency, is_headquarters, manager_name)
VALUES
('LOJA-01', 'PRUMO Ferragens — Loja Matriz Maputo', 'PRUMO Matriz', '400192834-01', '+258 84 399 2200', 'matriz@prumo.co.mz', 'Av. das FPLM, nº 2500, Maputo Central', 'Maputo', 'MT', true, 'Eng. Carlos Sitoe'),
('LOJA-02', 'PRUMO Ferragens — Filial 1 Matola Rio', 'PRUMO Matola', '400192834-02', '+258 84 555 3300', 'matola@prumo.co.mz', 'EN4 Km 12, Matola Rio', 'Matola', 'MT', false, 'Dra. Marta Machava'),
('LOJA-03', 'PRUMO Ferragens — Filial 2 Beira Porto', 'PRUMO Beira', '400192834-03', '+258 84 777 4400', 'beira@prumo.co.mz', 'Estrada Nacional 6, Manga, Beira', 'Beira', 'MT', false, 'Sr. Alberto Guambe')
ON CONFLICT (code) DO NOTHING;

-- Habilitar RLS (Row Level Security) permissivo para leitura/escrita autenticada
ALTER TABLE public.stores ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.profiles ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.products ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.product_stock ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.product_conversions ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.customers ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.suppliers ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.cash_sessions ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.cash_movements ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.sales ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.sale_items ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.store_transfers ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.losses ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.audit_logs ENABLE ROW LEVEL SECURITY;

-- Políticas de Acesso
ALTER TABLE public.embaixadores ENABLE ROW LEVEL SECURITY;
CREATE POLICY "Acesso público ou autenticado a embaixadores" ON public.embaixadores FOR ALL USING (true);
CREATE POLICY "Acesso público ou autenticado a lojas" ON public.stores FOR ALL USING (true);
CREATE POLICY "Acesso a perfis" ON public.profiles FOR ALL USING (true);
CREATE POLICY "Acesso a produtos" ON public.products FOR ALL USING (true);
CREATE POLICY "Acesso a estoque" ON public.product_stock FOR ALL USING (true);
CREATE POLICY "Acesso a conversões" ON public.product_conversions FOR ALL USING (true);
CREATE POLICY "Acesso a clientes" ON public.customers FOR ALL USING (true);
CREATE POLICY "Acesso a fornecedores" ON public.suppliers FOR ALL USING (true);
CREATE POLICY "Acesso a turnos" ON public.cash_sessions FOR ALL USING (true);
CREATE POLICY "Acesso a movimentos de caixa" ON public.cash_movements FOR ALL USING (true);
CREATE POLICY "Acesso a vendas" ON public.sales FOR ALL USING (true);
CREATE POLICY "Acesso a itens de venda" ON public.sale_items FOR ALL USING (true);
CREATE POLICY "Acesso a transferências" ON public.store_transfers FOR ALL USING (true);
CREATE POLICY "Acesso a perdas" ON public.losses FOR ALL USING (true);
CREATE POLICY "Acesso a auditoria" ON public.audit_logs FOR ALL USING (true);

-- 16. View de Monitoramento SaaS de Lojas
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

