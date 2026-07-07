CREATE TABLE public.announcements (
    content text NOT NULL,
    title text NOT NULL,
    id uuid NOT NULL DEFAULT gen_random_uuid(),
    building_id uuid,
    author_id uuid,
    created_at timestamp with time zone DEFAULT now(),
    type text DEFAULT 'info'::text
);

CREATE TABLE public.buildings (
    chairman_id uuid NOT NULL,
    id uuid NOT NULL DEFAULT gen_random_uuid(),
    updated_at timestamp with time zone NOT NULL DEFAULT now(),
    created_at timestamp with time zone NOT NULL DEFAULT now(),
    apartment_count integer DEFAULT 0,
    address text NOT NULL
);

CREATE TABLE public.calls (
    caller_id uuid,
    id uuid NOT NULL DEFAULT uuid_generate_v4(),
    channel_name text NOT NULL,
    receiver_id uuid,
    status text DEFAULT 'ringing'::text,
    created_at timestamp with time zone DEFAULT now()
);

CREATE TABLE public.documents (
    updated_at timestamp with time zone NOT NULL DEFAULT now(),
    id uuid NOT NULL DEFAULT gen_random_uuid(),
    title text NOT NULL,
    description text,
    category text,
    file_url text,
    is_premium boolean NOT NULL DEFAULT false,
    created_at timestamp with time zone NOT NULL DEFAULT now(),
    price integer DEFAULT 0
);

CREATE TABLE public.jobs (
    created_at timestamp with time zone DEFAULT now(),
    status text DEFAULT 'pending'::text,
    description text,
    title text NOT NULL,
    id uuid NOT NULL DEFAULT gen_random_uuid(),
    client_id uuid NOT NULL,
    master_id uuid NOT NULL,
    price numeric,
    updated_at timestamp with time zone DEFAULT now()
);

CREATE TABLE public.messages (
    receiver_id uuid,
    is_read boolean DEFAULT false,
    is_deleted boolean DEFAULT false,
    type text,
    image_url text,
    audio_url text,
    content text,
    task_id text,
    id uuid NOT NULL DEFAULT gen_random_uuid(),
    sender_id uuid,
    created_at timestamp with time zone NOT NULL DEFAULT timezone('utc'::text, now())
);

CREATE TABLE public.orders (
    description text,
    price numeric,
    created_at timestamp with time zone DEFAULT now(),
    lat double precision,
    lng double precision,
    chat_id uuid,
    id uuid NOT NULL DEFAULT uuid_generate_v4(),
    client_id uuid,
    master_id uuid,
    title text NOT NULL,
    status text DEFAULT 'pending'::text
);

CREATE TABLE public.portfolio (
    image_url text NOT NULL,
    id uuid NOT NULL DEFAULT gen_random_uuid(),
    master_id uuid,
    created_at timestamp with time zone NOT NULL DEFAULT timezone('utc'::text, now())
);

CREATE TABLE public.profiles (
    company_name text,
    id uuid NOT NULL DEFAULT gen_random_uuid(),
    user_id uuid,
    user_type user_type NOT NULL DEFAULT 'resident'::user_type,
    compliance_rating integer DEFAULT 0,
    is_whitelist_verified boolean DEFAULT false,
    created_at timestamp with time zone NOT NULL DEFAULT now(),
    updated_at timestamp with time zone NOT NULL DEFAULT now(),
    verification_status verification_status NOT NULL DEFAULT 'unverified'::verification_status,
    avg_rating double precision DEFAULT 0.0,
    is_verified boolean DEFAULT false,
    total_earned bigint DEFAULT '0'::bigint,
    is_online boolean DEFAULT true,
    earning_goal numeric DEFAULT '0'::numeric,
    building_id uuid,
    bin text,
    ownership_form text,
    services text,
    experience_description text,
    role text DEFAULT 'user'::text,
    full_name text,
    fcm_token text,
    business_name text,
    avatar_url text,
    bio text,
    specialization text,
    first_name text,
    last_name text,
    org_name text,
    city text,
    street text,
    house text,
    apartment text,
    email text,
    name text,
    phone text,
    address text
);

CREATE TABLE public.proposals (
    is_active boolean DEFAULT true,
    author_id uuid,
    description text,
    title text NOT NULL,
    id uuid NOT NULL DEFAULT uuid_generate_v4(),
    created_at timestamp with time zone DEFAULT now()
);

CREATE TABLE public.requests (
    title text NOT NULL,
    budget_max integer,
    budget_min integer,
    created_at timestamp with time zone NOT NULL DEFAULT now(),
    id uuid NOT NULL DEFAULT gen_random_uuid(),
    user_id uuid NOT NULL,
    status request_status NOT NULL DEFAULT 'pending'::request_status,
    progress integer DEFAULT 0,
    updated_at timestamp with time zone NOT NULL DEFAULT now(),
    deadline date,
    category text,
    assigned_contractor_id uuid,
    description text
);

CREATE TABLE public.reviews (
    created_at timestamp with time zone DEFAULT timezone('utc'::text, now()),
    to_worker_id uuid,
    rating integer,
    from_user_id uuid,
    task_id uuid,
    comment text,
    image_urls _text[],
    id uuid NOT NULL DEFAULT gen_random_uuid()
);

CREATE TABLE public.task_logs (
    created_at timestamp with time zone DEFAULT now(),
    task_id uuid,
    id uuid NOT NULL DEFAULT uuid_generate_v4(),
    action_text text NOT NULL
);

CREATE TABLE public.tasks (
    client_id uuid,
    contractor_id uuid,
    chairman_id uuid,
    created_at timestamp with time zone DEFAULT now(),
    id uuid NOT NULL DEFAULT gen_random_uuid(),
    status text DEFAULT 'new'::text,
    payment_status text DEFAULT 'pending'::text,
    image_url text,
    category text,
    address text,
    priority text DEFAULT 'medium'::text,
    apartment text,
    resident_phone text,
    title text NOT NULL,
    description text,
    building_id uuid,
    final_price integer DEFAULT 0,
    reserved_amount integer DEFAULT 0,
    master_lng double precision,
    master_lat double precision,
    is_deleted boolean DEFAULT false,
    master_id uuid,
    assignee_id uuid,
    user_id uuid
);

CREATE TABLE public.tender_bids (
    proposed_price integer NOT NULL,
    status text NOT NULL DEFAULT 'pending'::text,
    message text,
    created_at timestamp with time zone NOT NULL DEFAULT now(),
    proposed_deadline date,
    updated_at timestamp with time zone NOT NULL DEFAULT now(),
    tender_id uuid NOT NULL,
    contractor_id uuid NOT NULL,
    id uuid NOT NULL DEFAULT gen_random_uuid()
);

CREATE TABLE public.tenders (
    required_services _text[],
    region text DEFAULT 'Кокшетау'::text,
    id uuid NOT NULL DEFAULT gen_random_uuid(),
    budget integer,
    request_id uuid NOT NULL,
    created_at timestamp with time zone NOT NULL DEFAULT now(),
    status request_status NOT NULL DEFAULT 'pending'::request_status,
    title text NOT NULL,
    description text,
    deadline date
);

CREATE TABLE public.transactions (
    contractor_name text,
    request_id uuid,
    user_id uuid NOT NULL,
    id uuid NOT NULL DEFAULT gen_random_uuid(),
    description text,
    updated_at timestamp with time zone NOT NULL DEFAULT now(),
    amount integer NOT NULL,
    category text,
    receipt_url text,
    created_at timestamp with time zone NOT NULL DEFAULT now(),
    e_osi_report_id text,
    status transaction_status NOT NULL DEFAULT 'pending'::transaction_status,
    type transaction_type NOT NULL DEFAULT 'payment'::transaction_type
);

CREATE TABLE public.user_roles (
    user_id uuid NOT NULL,
    id uuid NOT NULL DEFAULT gen_random_uuid(),
    role app_role NOT NULL DEFAULT 'user'::app_role
);

CREATE TABLE public.user_tokens (
    user_id uuid,
    fcm_token text NOT NULL,
    created_at timestamp with time zone DEFAULT now(),
    id uuid NOT NULL DEFAULT uuid_generate_v4()
);

CREATE TABLE public.votes (
    id uuid NOT NULL DEFAULT gen_random_uuid(),
    signature_url text NOT NULL,
    choice text NOT NULL,
    proposal_id text NOT NULL,
    user_id uuid NOT NULL,
    created_at timestamp with time zone NOT NULL DEFAULT now()
);