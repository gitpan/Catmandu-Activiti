package Catmandu::Store::Activiti::HistoricProcessInstance;
use Catmandu::Sane;
use Catmandu::Util qw(:is :check);
use Activiti::Rest::Client;
use Moo;

with qw(Catmandu::Store);

has url => (
  is => 'ro',
  isa => sub { check_string($_[0]); },
  required => 1
);
has _activiti => (
  is => 'ro',
  lazy => 1,
  builder => '_build_activiti'
);
sub _build_activiti {
  my $self = $_[0];
  Activiti::Rest::Client->new(url => $self->url);
}

package Catmandu::Store::Activiti::HistoricProcessInstance::Bag;
use Moo;
use Catmandu::Util qw(:check :is :array);
use Catmandu::Hits;
use Carp qw(confess);
use Clone qw(clone);

with 'Catmandu::Bag';
with 'Catmandu::Searchable';

sub get {
  my($self,$id)=@_;
  my $res = $self->store->_activiti->historic_process_instances(
    processInstanceId => $id,
    start => 0,
    size => 1,
    includeProcessVariables => "true"
  )->parsed_content;
  $res->{size} || return;
  $res->{data}->[0];
}
sub generator {
  my $self = $_[0];
  sub {

    state $start = 0;
    state $size = 100;
    state $total;
    state $results = [];
    state $activiti = $self->_activiti();

    unless(@$results){

      if(defined $total){
        return if $start >= $total;
      }

      my $res = $activiti->historic_process_instances(
        start => $start,
        size => $size,
        includeProcessVariables => "true"
      )->parsed_content;

      $total = $res->{total};
      return unless @{ $res->{data} };

      $results = $res->{data};

      $start += $size;
    }

    shift @$results;
  };
}
sub add {
  die("not implemented");
  # POST runtime/process-instances                      start new process
  # PUT runtime/process-instances/:processInstanceId    activate|suspend an active process instance
  #
  # conclusion: real update of a process instance not interesting, i.e. does not follow Catmandu expectation of full data update
}
sub delete {  
  my($self,$id)=@_;
  $self->store->_activiti->delete_historic_process_instance(processInstanceId => $id)
}
sub search {
  my($self,%args)=@_;

  my $start = delete $args{start};
  my $limit = delete $args{limit};
  my $sort = delete $args{sort};
  my $order;
  if(defined($sort)){
    ($sort,$order) = split(' ',$sort);
    $order = array_includes([qw(asc desc)],$order) ? $order : "asc";
  }
  my $query = delete $args{query};
  my $content = defined($query) && is_hash_ref($query) ? clone($query) : {};

  $content->{start} = defined($start) ? $start : $content->{start};
  $content->{size} = defined($limit) ? $limit : $content->{size};
  $content->{sort} = $sort if defined $sort;
  $content->{order} = $order if defined $order;

  #see: http://www.activiti.org/userguide/#N153C2
  my $res = $self->store->_activiti->query_historic_process_instances(
    content => $content
  )->parsed_content;
  
  Catmandu::Hits->new({
    limit => $res->{size},
    start => $res->{start},
    total => $res->{total},
    hits  => $res->{data}
  });
}
sub searcher {
  die("not implemented");
}
sub delete_all {
  die("not supported");
}
sub delete_by_query {
  die("not supported");
}
sub translate_sru_sortkeys {
  die("not supported");
}
sub translate_cql_query {
  die("not supported");
}

1;
