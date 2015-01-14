/*
	Gerador de relatório do dicionário de dados do SQL Server
	Desenvolvido por JOÃO FELIPE BORGES PORTELA 
	http://www.joaofelipe.com/
	Versão 1.0 

	-----------------------------------------------------------------------------
	The MIT License (MIT)

	Copyright (c) 2015 João Felipe Portela

	Permission is hereby granted, free of charge, to any person obtaining a copy
	of this software and associated documentation files (the "Software"), to deal
	in the Software without restriction, including without limitation the rights
	to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
	copies of the Software, and to permit persons to whom the Software is
	furnished to do so, subject to the following conditions:

	The above copyright notice and this permission notice shall be included in all
	copies or substantial portions of the Software.

	THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
	IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
	FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
	AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
	LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
	OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
	SOFTWARE.
	-----------------------------------------------------------------------------
*/

IF  EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'[GerarDicionario]') AND type in (N'P', N'PC'))
DROP PROCEDURE GerarDicionario
GO
CREATE PROCEDURE GerarDicionario
    @ProjetoNome nvarchar(max) = 'NOME_DO_PROJETO', 
    @EmpresaLogo nvarchar(max) = 'URL_LOGO_DA_EMPRESA', 
    @EmpresaNome nvarchar(max) = 'NOME_DA_EMPRESA'
AS 

----------------------------------------------------------------------------------------------------------------
-- CRIAÇÃO DAS ESTRUTURAS E VARIÁVEIS INICIAIS
----------------------------------------------------------------------------------------------------------------

CREATE TABLE #htmlpage (conteudo TEXT NOT NULL);
INSERT INTO #htmlpage VALUES ('<html>
<head>
	<link rel="stylesheet" href="https://maxcdn.bootstrapcdn.com/bootstrap/3.2.0/css/bootstrap.min.css">
	<link rel="stylesheet" href="https://maxcdn.bootstrapcdn.com/bootstrap/3.2.0/css/bootstrap-theme.min.css">	
    <style>
        .cabecalho {
            padding: 50px 5% 0 5%;
        }
        .estrutura {
            padding: 0 5% 0 5%;
        }
        .logo {
            float: right;
            padding: 60px 40px 0 0;
        } 
		.center {
            text-align: center;
        }
        h4 {
            padding-top: 30px;
            font-weight: bold;
        }
        .table-striped > tbody > tr > th,
        .table-striped > tbody > tr > td {
            border-right: 1px dashed #cccbcb;
        }      
        .columnright {
            border-right: 0px !important;
        }
    </style>
	<script src="https://maxcdn.bootstrapcdn.com/bootstrap/3.2.0/js/bootstrap.min.js"></script>
</head>
<body>
	<div class="logo">
		<img src="' + @EmpresaLogo + '" alt="' + @EmpresaNome + '" />
	</div>
	<div class="cabecalho">
		<h1>Dicionário de dados</h1>
        <h3>' + @ProjetoNome + '</h3>
	</div>
    <hr />
	<div class="estrutura">
')

declare @tabela varchar(max)
declare @tdescription sql_variant
declare @iTabela int
set @iTabela = 1

update #htmlpage set conteudo = (select convert(varchar(max), conteudo) + '	<h4>Lista de Tabelas</h4>' + '
	<table class="table table-striped table-condensed">	
	<thead>
		<tr>
			<th>Nº</th>
			<th>Tabela</th>
			<th>Descrição</th>
		</tr>
	</thead>
	<tbody>' + char(13) from #htmlpage);

----------------------------------------------------------------------------------------------------------------
-- LISTA DE TABELAS
----------------------------------------------------------------------------------------------------------------

declare cursorTabelas cursor
	local
	fast_forward
	for select st.name [tabela], 
			   --sep.value [tdescription] 
			   isnull(sep.value, '<div class="center">-</div>') [tdescription]
		from sys.tables st
			left join sys.extended_properties sep on st.object_id = sep.major_id
												 and sep.name = 'MS_Description'
												 and sep.minor_id = '0'
		order by st.name
open cursorTabelas
while @iTabela <= (select count(st.name) from sys.tables st
				   where st.name <> 'sysdiagrams')
begin
	fetch cursorTabelas into @tabela, @tdescription

	update #htmlpage set conteudo = (select convert(varchar(max), conteudo) + '		<tr>' +
						char(13) + '			<td>' + convert(varchar(max),@iTabela) + '</td>' +
						char(13) + '			<td>' + convert(varchar(max),@tabela) + '</td>' +
						char(13) + '			<td class="columnright">' +  replace(convert(varchar(max),@tdescription),char(13),'<br />') + '</td>' +
						 '</tr>' + char(13) from #htmlpage) 

	set @iTabela = @iTabela + 1
end
close cursorTabelas
deallocate cursorTabelas

update #htmlpage set conteudo = (select convert(varchar(max), conteudo) + '</tbody>	</table>' + char(13) + char(13) from #htmlpage) 

----------------------------------------------------------------------------------------------------------------
-- GRID DE CADA TABELA
----------------------------------------------------------------------------------------------------------------

declare cursorTabela cursor
	local
	fast_forward
	for select st.name from sys.tables st
		order by st.name
		
set @iTabela = 1

open cursorTabela
while @iTabela <= (select count(st.name) from sys.tables st
				   where st.name <> 'sysdiagrams')
begin
	fetch cursorTabela into @tabela
	
	update #htmlpage set conteudo = (select convert(varchar(max), conteudo) + '	<h4>' + convert(varchar, @iTabela) + '. ' + @tabela + '</h4>' + '
	<table class="table table-striped table-condensed">	
	<thead>
		<tr>
			<th>Coluna</th>
			<th>Descrição</th>
			<th class="center">Tamanho</th>
			<th>Tipo</th>
		</tr>
	</thead>
	<tbody>' + char(13) from #htmlpage);

----------------------------------------------------------------------------------------------------------------
-- COLUNAS DO GRID DE TABELAS
----------------------------------------------------------------------------------------------------------------

	declare cursorColunas cursor
	local
	fast_forward
	for select 
			sc.name [column],
			isnull(sep.value, '<div class="center">-</div>') [description],
			sc.max_length [lenght],
			t.name [type]
		from sys.tables st
			inner join sys.columns sc on st.object_id = sc.object_id
			inner join sys.types t on sc.user_type_id = t.user_type_id
			left join sys.extended_properties sep on st.object_id = sep.major_id
												 and sc.column_id = sep.minor_id
												 and sep.name = 'MS_Description'
		where st.name = @tabela

	declare @icolumns int
	declare @column sql_variant
	declare @description sql_variant
	declare @lenght sql_variant
	declare @type sql_variant

	set @icolumns = 1

	open cursorColunas
	while @icolumns <= (select count(sc.name) from sys.tables st
						inner join sys.columns sc on st.object_id = sc.object_id
						where st.name = @tabela)
	begin
		fetch cursorColunas into @column, @description, @lenght, @type		
		update #htmlpage set conteudo = (select convert(varchar(max), conteudo) + '		<tr>' +
						char(13) + '			<td>' + convert(varchar(max),@column) + '</td>' +
						char(13) + '			<td>' + replace(convert(varchar(max),@description),char(13),'<br />') + '</td>' +
						char(13) + '			<td class="center">' + convert(varchar(max),@lenght) + '</td>' +
						char(13) + '			<td class="columnright">' + convert(varchar(max),@type) + '</td>' +
						 '</tr>' + char(13) from #htmlpage) 
		set @icolumns = @icolumns + 1
	end
	close cursorColunas
	deallocate cursorColunas
	
	update #htmlpage set conteudo = (select convert(varchar(max), conteudo) + '</tbody>	</table>' + char(13) + char(13) from #htmlpage) 
	set @iTabela = @iTabela + 1
end
close cursorTabela
deallocate cursorTabela

----------------------------------------------------------------------------------------------------------------
-- FINALIZAÇÃO
----------------------------------------------------------------------------------------------------------------

update #htmlpage set conteudo = (select convert(varchar(max), conteudo) + '
	</div>
</body>
</html>' from #htmlpage) 

select conteudo from #htmlpage

DROP TABLE #htmlpage

go