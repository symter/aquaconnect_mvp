-- Self-service institute signup (ported from aquaconnect_web without the
-- business-certificate upload / admin approval: accounts are usable
-- immediately).

alter table organizations
  add column business_reg_no text,
  add column address text,
  add column phone text,
  add column created_at timestamptz not null default now();
-- One institute per business registration number (when given).
create unique index organizations_business_reg_no_key on organizations(business_reg_no) where business_reg_no is not null;

-- Consent record — signup can't complete without the two required terms.
alter table members
  add column terms_version text,
  add column terms_agreed_at timestamptz,
  add column privacy_agreed_at timestamptz,
  add column marketing_agreed boolean not null default false;

-- Login lowercases the email, so uniqueness must ignore case too.
create unique index members_email_lower_key on members(lower(email));
