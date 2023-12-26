{{$svrType := .ServiceType}}
{{$svrName := .ServiceName}}

{{- range .MethodSets}}
const Operation{{$svrType}}{{.OriginalName}} = "/{{$svrName}}/{{.OriginalName}}"
{{- end}}

type {{.ServiceType}}HTTPServer interface {
{{- range .MethodSets}}
	{{- if ne .Comment ""}}
	{{.Comment}}
	{{- end}}
	{{.Name}}(context.Context, *{{.Request}}) (*{{.Reply}}, error)
{{- end}}
}

type Register{{.ServiceType}}HTTPResult struct{}

func (*Register{{.ServiceType}}HTTPResult) String() string {
    return "{{.ServiceType}}HTTPServer"
}

func Register{{.ServiceType}}ServerHTTPProvider(newer interface{}) []interface{} {
	return []interface{}{
		// For provide dependency
		fx.Annotate(
			newer,
			fx.As(new({{.ServiceType}}HTTPServer)),
		),
		// For create instance
		fx.Annotate(
			Register{{.ServiceType}}HTTPProviderImpl,
			fx.As(new(fmt.Stringer)),
			fx.ResultTags(`group:"http_register"`),
		),
	}
}

// Register{{.ServiceType}}ProviderImpl use to trigger register
func Register{{.ServiceType}}HTTPProviderImpl(s *http.Server, srv {{.ServiceType}}HTTPServer) *Register{{.ServiceType}}HTTPResult {
	Register{{.ServiceType}}HTTPServer(s, srv)
	return &Register{{.ServiceType}}HTTPResult{}
}


func Register{{.ServiceType}}HTTPServer(s *http.Server, srv {{.ServiceType}}HTTPServer) {
	r := s.Route("/")
	{{- range .Methods}}
	r.{{.Method}}("{{.Path}}", _{{$svrType}}_{{.Name}}{{.Num}}_HTTP_Handler(srv))
	{{- end}}
}

{{range .Methods}}
func _{{$svrType}}_{{.Name}}{{.Num}}_HTTP_Handler(srv {{$svrType}}HTTPServer) func(ctx http.Context) error {
	return func(ctx http.Context) error {
		var in {{.Request}}
		{{- if .HasBody}}
		if err := ctx.Bind(&in{{.Body}}); err != nil {
			return err
		}
		{{- end}}
		if err := ctx.BindQuery(&in); err != nil {
			return err
		}
		{{- if .HasVars}}
		if err := ctx.BindVars(&in); err != nil {
			return err
		}
		{{- end}}
		http.SetOperation(ctx,Operation{{$svrType}}{{.OriginalName}})
		h := ctx.Middleware(func(ctx context.Context, req interface{}) (interface{}, error) {
			return srv.{{.Name}}(ctx, req.(*{{.Request}}))
		})
		out, err := h(ctx, &in)
		if err != nil {
			return err
		}
		reply := out.(*{{.Reply}})
		return ctx.Result(200, reply{{.ResponseBody}})
	}
}
{{end}}

type {{.ServiceType}}HTTPClient interface {
{{- range .MethodSets}}
	{{.Name}}(ctx context.Context, req *{{.Request}}, opts ...http.CallOption) (rsp *{{.Reply}}, err error)
{{- end}}
	RegisterNameForDiscover() string

}

func register{{.ServiceType}}ClientHTTPNameProvider() []string {
	return []string{"{{.RegistryName}}", "http"}
}

func Register{{.ServiceType}}ClientHTTPProvider(creator interface{}) []interface{} {
	return []interface{}{
		fx.Annotate(
			New{{.ServiceType}}HTTPClient,
			fx.As(new({{.ServiceType}}HTTPClient)),
			fx.ParamTags(`name:"{{.RegistryName}}/http"`),
		),
		fx.Annotate(
			creator,
			// fx.As(new(*http.Client)),
			fx.ParamTags(`name:"{{.RegistryName}}/http/name"`),
			fx.ResultTags(`name:"{{.RegistryName}}/http"`),
		),
		fx.Annotate(
			register{{.ServiceType}}ClientHTTPNameProvider,
			fx.ResultTags(`name:"{{.RegistryName}}/http/name"`),
		),
	}
}


type {{.ServiceType}}HTTPClientImpl struct{
	cc *http.Client
}

func New{{.ServiceType}}HTTPClient (client *http.Client) {{.ServiceType}}HTTPClient {
	return &{{.ServiceType}}HTTPClientImpl{client}
}

func (c *{{$svrType}}HTTPClientImpl) RegisterNameForDiscover() string {
    return "{{.RegistryName}}"
}


{{range .MethodSets}}
func (c *{{$svrType}}HTTPClientImpl) {{.Name}}(ctx context.Context, in *{{.Request}}, opts ...http.CallOption) (*{{.Reply}}, error) {
	var out {{.Reply}}
	pattern := "{{.Path}}"
	path := binding.EncodeURL(pattern, in, {{not .HasBody}})
	opts = append(opts, http.Operation(Operation{{$svrType}}{{.OriginalName}}))
	opts = append(opts, http.PathTemplate(pattern))
	{{if .HasBody -}}
	err := c.cc.Invoke(ctx, "{{.Method}}", path, in{{.Body}}, &out{{.ResponseBody}}, opts...)
	{{else -}}
	err := c.cc.Invoke(ctx, "{{.Method}}", path, nil, &out{{.ResponseBody}}, opts...)
	{{end -}}
	if err != nil {
		return nil, err
	}
	return &out, err
}
{{end}}
