resource "aws_vpc" "main" {
  cidr_block           = var.vpc_cidr
  enable_dns_support   = true
  enable_dns_hostnames = true

  tags = {
    Name = "${var.name_prefix}-vpc"
  }
}

resource "aws_internet_gateway" "main" {
  vpc_id = aws_vpc.main.id

  tags = {
    Name = "${var.name_prefix}-igw"
  }
}

# Só ALB e NAT. Os nodes ficam nas privadas.
resource "aws_subnet" "public" {
  for_each = var.public_subnet

  vpc_id                  = aws_vpc.main.id
  availability_zone       = each.value.availability_zone
  cidr_block              = each.value.cidr_block
  map_public_ip_on_launch = false

  # Onde o Load Balancer Controller cria ALBs públicos.
  tags = {
    Name                     = "${var.name_prefix}-public-${each.key}"
    Tier                     = "public"
    "kubernetes.io/role/elb" = "1"
  }
}

# Nodes e pods do EKS. Saída pelo NAT, sem entrada da internet.
resource "aws_subnet" "private" {
  for_each = var.private_subnet

  vpc_id            = aws_vpc.main.id
  availability_zone = each.value.availability_zone
  cidr_block        = each.value.cidr_block

  # Onde o Load Balancer Controller cria load balancers internos.
  tags = {
    Name                              = "${var.name_prefix}-private-${each.key}"
    Tier                              = "private"
    "kubernetes.io/role/internal-elb" = "1"
  }
}

resource "aws_eip" "nat" {
  domain = "vpc"

  tags = {
    Name = "${var.name_prefix}-nat-eip"
  }

  depends_on = [aws_internet_gateway.main]
}

resource "aws_nat_gateway" "main" {
  allocation_id = aws_eip.nat.id
  subnet_id     = aws_subnet.public[local.nat_subnet_key].id

  tags = {
    Name = "${var.name_prefix}-nat"
  }

  depends_on = [aws_internet_gateway.main]
}

resource "aws_route_table" "public" {
  vpc_id = aws_vpc.main.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.main.id
  }

  tags = {
    Name = "${var.name_prefix}-public-rt"
  }
}

resource "aws_route_table" "private" {
  vpc_id = aws_vpc.main.id

  route {
    cidr_block     = "0.0.0.0/0"
    nat_gateway_id = aws_nat_gateway.main.id
  }

  tags = {
    Name = "${var.name_prefix}-private-rt"
  }
}

resource "aws_route_table_association" "public" {
  for_each = aws_subnet.public

  subnet_id      = each.value.id
  route_table_id = aws_route_table.public.id
}

resource "aws_route_table_association" "private" {
  for_each = aws_subnet.private

  subnet_id      = each.value.id
  route_table_id = aws_route_table.private.id
}

# A tabela principal da VPC não é associada a nenhuma subnet. Gerenciada só
# para ficar nomeada e sem rotas além da local.
resource "aws_default_route_table" "main" {
  default_route_table_id = aws_vpc.main.default_route_table_id

  tags = {
    Name = "${var.name_prefix}-main-rt-sem-uso"
  }
}

# Esvazia o SG default, que nasce liberando tráfego entre membros.
resource "aws_default_security_group" "main" {
  vpc_id = aws_vpc.main.id

  tags = {
    Name = "${var.name_prefix}-default-sg-bloqueado"
  }
}

resource "aws_cloudwatch_log_group" "flow_log" {
  # checkov:skip=CKV_AWS_158: chave gerenciada pela AWS basta aqui.
  # checkov:skip=CKV_AWS_338: ambiente efêmero, retenção curta.
  count = var.enable_flow_log ? 1 : 0

  name              = "/${var.name_prefix}/vpc-flow-log"
  retention_in_days = var.flow_log_retention_day

  tags = {
    Name = "${var.name_prefix}-flow-log"
  }
}

data "aws_iam_policy_document" "flow_log_assume_role" {
  statement {
    effect  = "Allow"
    actions = ["sts:AssumeRole"]

    principals {
      type        = "Service"
      identifiers = ["vpc-flow-logs.amazonaws.com"]
    }
  }
}

data "aws_iam_policy_document" "flow_log" {
  statement {
    effect = "Allow"
    actions = [
      "logs:CreateLogStream",
      "logs:PutLogEvents",
      "logs:DescribeLogStreams",
    ]
    resources = ["${try(aws_cloudwatch_log_group.flow_log[0].arn, "")}:*"]
  }
}

resource "aws_iam_role" "flow_log" {
  count = var.enable_flow_log ? 1 : 0

  name               = "${var.name_prefix}-flow-log-role"
  assume_role_policy = data.aws_iam_policy_document.flow_log_assume_role.json
}

resource "aws_iam_role_policy" "flow_log" {
  count = var.enable_flow_log ? 1 : 0

  name   = "${var.name_prefix}-flow-log-policy"
  role   = aws_iam_role.flow_log[0].id
  policy = data.aws_iam_policy_document.flow_log.json
}

resource "aws_flow_log" "main" {
  count = var.enable_flow_log ? 1 : 0

  vpc_id               = aws_vpc.main.id
  traffic_type         = "ALL"
  iam_role_arn         = aws_iam_role.flow_log[0].arn
  log_destination_type = "cloud-watch-logs"
  log_destination      = aws_cloudwatch_log_group.flow_log[0].arn

  tags = {
    Name = "${var.name_prefix}-flow-log"
  }
}
